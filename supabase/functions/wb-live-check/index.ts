// Supabase Edge Function: wb-live-check
//
// Checks a student's in-progress handwritten work WHILE they're still
// writing it — called from either the public, unauthenticated
// /whiteboard/:id assignment board, or the public /study free-practice
// canvas (no login exists for students at all), so unlike wb-grade this
// function takes NO Authorization header and must do its own privileged
// read using the service-role key (never exposed to the client) rather
// than a forwarded session. Pass question_id for a formal assignment
// question, or course_id for free-study practice (grounded in that
// course's course_knowledge digest instead of a specific rubric). It only
// returns which numbered LINE BADGES (rendered into the image client-side
// — see whiteboard_rasterizer.dart) look wrong, plus a short note per
// line; it never returns or leaks the question's model answer/rubric, or
// the full course knowledge digest, itself.
//
// Deploy: paste this file's contents into
//   Supabase Dashboard -> Edge Functions -> wb-live-check -> Code
// (or `supabase functions deploy wb-live-check` if you have the CLI).
// No new secret needed: reuses the "QUIZ" Gemini key.

import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// The fastest free model — a live check needs to feel instant (target:
// flagged within ~3s of the student finishing a line), not thorough.
const GEMINI_MODEL = "gemini-3.6-flash-lite";

const LIVE_CHECK_SCHEMA = {
  type: "OBJECT",
  properties: {
    state: {
      type: "STRING",
      enum: ["empty", "on_track", "minor_error", "critical_error"],
    },
    wrong: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          line: { type: "INTEGER" },
          severity: { type: "STRING", enum: ["critical", "minor"] },
          note: { type: "STRING" },
        },
        required: ["line", "severity", "note"],
      },
    },
    message: { type: "STRING" },
  },
  required: ["state", "wrong"],
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Base safety net from the spec: never let a note/message contain the
// model answer's exact text verbatim, even if the model slips — the prompt
// already forbids it, this is just a second line of defense.
function redactAnswer(text: string, modelAnswer: string | null): string {
  if (!modelAnswer) return text;
  const needle = modelAnswer.trim();
  if (needle.length < 2 || needle.length > 60) return text;
  return text.split(needle).join("***");
}

interface CheckContext {
  subject: string;
  language: string;
  /** Set for a formal assignment question; unset for free-study practice. */
  question?: string;
  modelAnswer?: string | null;
  rubric?: unknown;
  acceptedVariations?: string | null;
  /** Set for free-study practice: the course's cached Drive-material digest. */
  knowledgeSummary?: string | null;
}

async function liveCheckWithGemini(
  context: CheckContext,
  imageBase64: string,
  geminiApiKey: string,
) {
  const language = context.language === "en" ? "en" : "ar";
  const languageNote = language === "en"
    ? "Write notes/message in English."
    : "اكتب الملاحظات بالعربية المصرية البسيطة.";

  const contextParts: string[] = [`Subject: ${context.subject}`];
  if (context.question) {
    contextParts.push(`Question: ${context.question}`);
  } else {
    contextParts.push(
      `This is free self-study practice, not a specific assigned question — the student is solving a problem ` +
        `of their own (shown in the image, possibly as an uploaded screenshot with the student's handwritten ` +
        `solution below/around it). Judge general correctness for this subject using your own knowledge plus the ` +
        `course reference notes below.`,
    );
  }
  if (context.modelAnswer) {
    contextParts.push(`Model/expected answer: ${context.modelAnswer}`);
  }
  if (Array.isArray(context.rubric) && context.rubric.length > 0) {
    contextParts.push(`Rubric: ${JSON.stringify(context.rubric)}`);
  }
  if (context.acceptedVariations) {
    contextParts.push(
      `Accepted variations in the answer: ${context.acceptedVariations}`,
    );
  }
  if (context.knowledgeSummary) {
    contextParts.push(
      `Course reference notes (conventions/formulas/method this course uses — use these to judge correctness, ` +
        `but they are not a question-specific answer key):\n${context.knowledgeSummary}`,
    );
  }

  const prompt =
    `You are watching a student solve a problem live, one line at a time, in the attached image. ` +
    `${contextParts.join("\n")}\n` +
    `Numbers in blue circles on the LEFT of the image are LINE LABELS only — they are not part of the ` +
    `solution. Each labeled line is roughly one step. ` +
    `Rules: incomplete is NOT wrong — only flag a line that is itself clearly, definitely wrong. Any correct ` +
    `method is accepted; "accepted_variations" above overrides the model answer. If handwriting is unreadable, ` +
    `do not flag that line at all (never guess wrong). "critical" = this mistake makes the rest of the solution ` +
    `wrong; "minor" = a small slip (units, notation, sign) that doesn't invalidate the method. ` +
    `NEVER state the final numeric/symbolic answer in a note or in "message" — give a hint toward the mistake, ` +
    `not the fix. Be extremely brief: each note is one short sentence. ` +
    `${languageNote} ` +
    `Return ONLY the JSON object matching the given schema — state is "empty" if nothing is written yet, ` +
    `"critical_error"/"minor_error" if "wrong" is non-empty, otherwise "on_track". "wrong" lists only the line ` +
    `numbers that are actually wrong (can be empty).`;

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
      responseSchema: LIVE_CHECK_SCHEMA,
    },
  };

  // Fail fast rather than the long generate-quiz/wb-grade backoff chain —
  // a live check that blocks 30s defeats the point; the next debounce
  // cycle will just try again a couple of seconds later.
  const maxAttempts = 2;
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
    await new Promise((resolve) => setTimeout(resolve, 1500));
  }
  if (!res!.ok) {
    throw new Error(`Gemini API error (${res!.status})`);
  }
  const data = await res!.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("Gemini رجّع رد فاضي");

  let result: {
    state?: string;
    wrong?: { line: number; severity: string; note: string }[];
    message?: string;
  };
  try {
    result = JSON.parse(text);
  } catch {
    throw new Error("Gemini رجّع JSON مش مكتوب صح");
  }

  const modelAnswer = context.modelAnswer ?? null;
  const wrong = (result.wrong ?? []).map((w) => ({
    line: w.line,
    severity: w.severity === "critical" ? "critical" : "minor",
    note: redactAnswer(w.note ?? "", modelAnswer),
  }));
  return {
    state: result.state ?? "on_track",
    wrong,
    message: result.message ? redactAnswer(result.message, modelAnswer) : null,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const geminiApiKey = Deno.env.get("QUIZ");
    if (!geminiApiKey) {
      return jsonResponse(
        { error: "مفيش GEMINI_API_KEY متظبط في Supabase secrets" },
        500,
      );
    }

    const { question_id, course_id, image_base64 } = await req.json();
    if ((!question_id && !course_id) || !image_base64) {
      return jsonResponse(
        { error: "بيانات ناقصة (question_id أو course_id / image_base64)" },
        400,
      );
    }

    // Service-role client — this call has no user session at all (public
    // board/study mode, no student login), so this is the only way to read
    // the privileged rows (model_answer/rubric, or the course's knowledge
    // digest) that anon's column-level grants deliberately exclude. Never
    // forwarded to the client.
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );

    let context: CheckContext;

    if (question_id) {
      // Only serve a question that actually belongs to a currently-
      // published assignment — same gate the public RLS policy enforces,
      // re-implemented here by hand since the service-role key bypasses
      // RLS entirely.
      const { data: published } = await supabase
        .from("wb_assignments")
        .select("id")
        .eq("is_published", true)
        .contains("question_ids", [question_id])
        .limit(1)
        .maybeSingle();
      if (!published) {
        return jsonResponse({ error: "السؤال غير متاح" }, 404);
      }

      const { data: question, error: qError } = await supabase
        .from("wb_questions")
        .select("*")
        .eq("id", question_id)
        .single();
      if (qError || !question) {
        return jsonResponse({ error: "السؤال غير موجود" }, 404);
      }

      context = {
        subject: question.subject_pack ?? "عام",
        language: question.language ?? "ar",
        question: question.prompt,
        modelAnswer: question.model_answer,
        rubric: question.rubric,
        acceptedVariations: question.accepted_variations,
      };
    } else {
      // Free-study mode: only serve a course that's actually active —
      // same gate the public RLS policy enforces.
      const { data: course, error: courseError } = await supabase
        .from("courses")
        .select("id, subject_name, status")
        .eq("id", course_id)
        .eq("status", "active")
        .maybeSingle();
      if (courseError || !course) {
        return jsonResponse({ error: "الكورس غير متاح" }, 404);
      }

      const { data: knowledge } = await supabase
        .from("course_knowledge")
        .select("summary")
        .eq("course_id", course_id)
        .maybeSingle();

      context = {
        subject: course.subject_name,
        language: "ar",
        knowledgeSummary: knowledge?.summary ?? null,
      };
    }

    const result = await liveCheckWithGemini(
      context,
      image_base64,
      geminiApiKey,
    );
    return jsonResponse(result);
  } catch (e) {
    return jsonResponse(
      { error: String(e instanceof Error ? e.message : e) },
      500,
    );
  }
});
