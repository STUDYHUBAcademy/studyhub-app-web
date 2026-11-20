// Supabase Edge Function: wb-grade
//
// Grades one whiteboard submission with Gemini. The Flutter app rasterizes
// the submission's strokes (plus the question's background, if any) into a
// single PNG client-side — Deno has no Flutter runtime to render strokes
// itself — and sends that image here as base64, along with the submission
// id. This function re-fetches the submission + its question using the
// CALLER's own Supabase session (not a service-role key), so the normal
// owners_full_access RLS policy is what actually authorizes the read and
// the write-back. No secret ever reaches the Flutter app; the only secret
// this function needs (the Gemini API key) lives in Supabase's own Edge
// Function secrets, under the same "QUIZ" name the quiz generator uses.
//
// Deploy: paste this file's contents into
//   Supabase Dashboard -> Edge Functions -> wb-grade -> Code
// (or `supabase functions deploy wb-grade` if you have the CLI).

import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const GEMINI_MODEL = "gemini-3.6-flash";

const GRADE_SCHEMA = {
  type: "OBJECT",
  properties: {
    score: { type: "NUMBER" },
    feedback: { type: "STRING" },
  },
  required: ["score", "feedback"],
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function gradeWithGemini(
  question: Record<string, unknown>,
  imageBase64: string,
  geminiApiKey: string,
) {
  const language = (question.language as string) === "en" ? "en" : "ar";
  const languageNote = language === "en"
    ? "Write the feedback in English."
    : "اكتب التصحيح والتعليق باللغة العربية الفصحى (Modern Standard Arabic) فقط — لا تستخدم أي لهجة عامية.";

  const contextParts: string[] = [
    `Subject: ${question.subject_pack ?? "عام"}`,
    `Question: ${question.prompt}`,
  ];
  if (question.model_answer) {
    contextParts.push(`Model/expected answer: ${question.model_answer}`);
  }
  if (Array.isArray(question.rubric) && question.rubric.length > 0) {
    contextParts.push(`Rubric: ${JSON.stringify(question.rubric)}`);
  }
  if (question.accepted_variations) {
    contextParts.push(
      `Accepted variations in the answer: ${question.accepted_variations}`,
    );
  }
  const maxScore = Number(question.max_score ?? 10);

  const prompt =
    `You are a strict but fair tutor grading a student's handwritten solution, shown in the attached image. ` +
    `${contextParts.join("\n")}\n` +
    `Read the student's handwriting carefully — it may be messy. Judge the METHOD and final result, not ` +
    `handwriting neatness. Give partial credit for correct steps even if the final answer is wrong, and give ` +
    `partial credit if the final answer is right but the method shown is flawed or missing. ` +
    `Score strictly between 0 and ${maxScore} (can be a decimal). ` +
    `Write feedback as 2-4 short sentences: what was correct, what was wrong or missing, and the single most useful ` +
    `thing the student should fix. Be specific — reference the actual steps/numbers you see in the image, not ` +
    `generic advice. ${languageNote} ` +
    `Return ONLY the JSON object matching the given schema, nothing else.`;

  const body = {
    contents: [
      {
        parts: [
          { inline_data: { mime_type: "image/png", data: imageBase64 } },
          { text: prompt },
        ],
      },
    ],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: GRADE_SCHEMA,
    },
  };

  // Same retry/backoff as generate-quiz — Gemini's free-tier capacity
  // occasionally returns a transient 503 "model overloaded".
  const maxAttempts = 5;
  const backoffMs = [2000, 4000, 8000, 16000];
  let res: Response | null = null;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": geminiApiKey,
        },
        body: JSON.stringify(body),
      },
    );
    if (res.ok || res.status !== 503 || attempt === maxAttempts) break;
    await new Promise((resolve) => setTimeout(resolve, backoffMs[attempt - 1]));
  }
  if (!res!.ok) {
    if (res!.status === 503) {
      throw new Error(
        "الخدمة مزدحمة جدًا دلوقت (الطلبات على Gemini كتير) — جرّب تاني بعد دقيقة أو اتنين.",
      );
    }
    let detail = await res!.text();
    try {
      const parsed = JSON.parse(detail);
      detail = parsed?.error?.message ?? detail;
    } catch {
      // not JSON — keep the raw text
    }
    throw new Error(`Gemini API error (${res!.status}): ${detail}`);
  }
  const data = await res!.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("Gemini رجّع رد فاضي — جرّب تاني");

  let result: { score?: number; feedback?: string };
  try {
    result = JSON.parse(text);
  } catch {
    throw new Error("Gemini رجّع JSON مش مكتوب صح");
  }
  if (typeof result.score !== "number" || !result.feedback) {
    throw new Error("Gemini رجّع نتيجة ناقصة");
  }
  const score = Math.max(0, Math.min(maxScore, result.score));
  return { score, maxScore, feedback: result.feedback };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "محتاج تسجيل دخول" }, 401);
    }

    const geminiApiKey = Deno.env.get("QUIZ");
    if (!geminiApiKey) {
      return jsonResponse(
        { error: "مفيش GEMINI_API_KEY متظبط في Supabase secrets" },
        500,
      );
    }

    const { submission_id, image_base64 } = await req.json();
    if (!submission_id || !image_base64) {
      return jsonResponse(
        { error: "بيانات ناقصة (submission_id/image_base64)" },
        400,
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: { headers: { Authorization: authHeader } },
        auth: { persistSession: false, autoRefreshToken: false },
      },
    );

    const { data: submission, error: subError } = await supabase
      .from("wb_submissions")
      .select("id, question_id")
      .eq("id", submission_id)
      .single();
    if (subError || !submission) {
      return jsonResponse({ error: "التسليم غير موجود" }, 404);
    }

    const { data: question, error: qError } = await supabase
      .from("wb_questions")
      .select("*")
      .eq("id", submission.question_id)
      .single();
    if (qError || !question) {
      return jsonResponse({ error: "السؤال غير موجود" }, 404);
    }

    const { score, maxScore, feedback } = await gradeWithGemini(
      question,
      image_base64,
      geminiApiKey,
    );

    const { error: updateError } = await supabase
      .from("wb_submissions")
      .update({
        ai_score: score,
        ai_max_score: maxScore,
        ai_feedback: feedback,
        ai_graded_at: new Date().toISOString(),
      })
      .eq("id", submission_id);
    if (updateError) {
      return jsonResponse(
        { error: `فشل حفظ التصحيح: ${updateError.message}` },
        500,
      );
    }

    return jsonResponse({ score, max_score: maxScore, feedback });
  } catch (e) {
    return jsonResponse(
      { error: String(e instanceof Error ? e.message : e) },
      500,
    );
  }
});
