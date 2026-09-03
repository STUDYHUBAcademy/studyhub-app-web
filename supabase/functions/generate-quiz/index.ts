// Supabase Edge Function: generate-quiz
//
// Reads one or more Google Drive files (the owner already picked them in
// the app and forwarded a short-lived Drive-readonly access token), asks
// Gemini to draft a multiple-choice quiz from their content, and inserts
// the resulting quiz row — using the CALLER's own Supabase session (not a
// service-role key), so the normal owners_full_access RLS policy is what
// actually authorizes the write. No secret ever reaches the Flutter app;
// the only secret this function needs (GEMINI_API_KEY) lives in Supabase's
// own Edge Function secrets.
//
// Deploy: paste this file's contents into
//   Supabase Dashboard -> Edge Functions -> generate-quiz -> Code
// (or `supabase functions deploy generate-quiz` if you have the CLI).

import { createClient } from "npm:@supabase/supabase-js@2";
import { encodeBase64 } from "jsr:@std/encoding@1/base64";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const GEMINI_MODEL = "gemini-3.6-flash";
const GOOGLE_NATIVE_MIME_TYPES = new Set([
  "application/vnd.google-apps.document",
  "application/vnd.google-apps.presentation",
  "application/vnd.google-apps.spreadsheet",
]);

const QUESTIONS_SCHEMA = {
  type: "ARRAY",
  items: {
    type: "OBJECT",
    properties: {
      topic: { type: "STRING" },
      text: { type: "STRING" },
      options: { type: "ARRAY", items: { type: "STRING" } },
      correct_index: { type: "INTEGER" },
    },
    required: ["text", "options", "correct_index"],
  },
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// The Edge Function worker has a hard memory ceiling — a large PDF can
// easily blow past it once you account for the raw bytes, the base64
// copy, and the JSON body sent to Gemini all needing to coexist in
// memory. Guard with a friendly error instead of a cryptic worker crash.
const MAX_FILE_BYTES = 12 * 1024 * 1024; // 12MB

/// Fetches one Drive file as PDF bytes — exporting Google-native docs to
/// PDF, or downloading already-binary files (PDF and friends) as-is.
async function fetchFileAsPdf(
  file: { id: string; mime_type?: string | null },
  driveAccessToken: string,
): Promise<{ base64: string; mimeType: string }> {
  const isGoogleNative = GOOGLE_NATIVE_MIME_TYPES.has(file.mime_type ?? "");
  const url = isGoogleNative
    ? `https://www.googleapis.com/drive/v3/files/${file.id}/export?mimeType=application/pdf`
    : `https://www.googleapis.com/drive/v3/files/${file.id}?alt=media`;

  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${driveAccessToken}` },
  });
  if (!res.ok) {
    throw new Error(
      `تعذّر تحميل ملف Drive (${file.id}): ${res.status} ${await res.text()}`,
    );
  }
  const bytes = new Uint8Array(await res.arrayBuffer());
  if (bytes.length > MAX_FILE_BYTES) {
    const mb = (bytes.length / (1024 * 1024)).toFixed(1);
    throw new Error(
      `الملف كبير جدًا (${mb} ميجا) — أقصى حجم مدعوم حاليًا ${
        MAX_FILE_BYTES / (1024 * 1024)
      } ميجا. جرّب ملف أصغر أو قسّمه.`,
    );
  }
  const mimeType = isGoogleNative
    ? "application/pdf"
    : file.mime_type || "application/pdf";
  return { base64: encodeBase64(bytes), mimeType };
}

async function generateQuestions(
  fileParts: { base64: string; mimeType: string }[],
  direction: string,
  geminiApiKey: string,
) {
  const languageNote =
    direction === "ltr"
      ? "The source content is in English — write the quiz in English."
      : "المحتوى بالعربي — اكتب الأسئلة بالعربي.";

  const prompt =
    `You are drafting a self-check multiple-choice quiz for a tutoring academy from the attached lecture file(s). ` +
    `Let the NUMBER of questions be driven by how much substantive content is actually there — enough to meaningfully ` +
    `cover every major concept and worked example, but never pad with repetitive or trivial filler questions just to ` +
    `hit a target count. A short, narrow file might only deserve 5-8 questions; a long, dense chapter might deserve ` +
    `25+. Do not aim for a fixed number. ` +
    `PRIORITIZE two things above generic concept-testing: (1) any worked/solved example in the material — write ` +
    `question(s) that test the specific method, reasoning, or numeric result of that exact example; (2) any ` +
    `practice question, exercise, or problem already present in the file itself — adapt each one into a multiple-` +
    `choice question (converting a free-response problem into one correct answer + 3 plausible distractors) rather ` +
    `than skipping it. Only after covering worked examples and existing questions, add further questions on other ` +
    `key concepts the file covers. ` +
    `Each question needs exactly 4 plausible options and a 0-based correct_index. ` +
    `Set "topic" to a short label for the section/concept the question covers (used to group weak-area feedback) — ` +
    `reuse the same topic label for multiple questions from the same section. ` +
    `If a question depends on a diagram, figure, or circuit shown in the file (and isn't already fully worked-example ` +
    `numbers you can just state), you cannot show that image to the student — instead make the question fully ` +
    `self-contained by describing the diagram's exact configuration/values in the question text itself (e.g. state ` +
    `the component values and connections of a circuit in words) rather than saying "refer to the figure". ` +
    `Write any mathematical expression, formula, or symbol (in the question text or in an option) as LaTeX wrapped ` +
    `in single dollar signs, e.g. $\\sigma = P/A$ or $\\tau_{avg} = \\frac{P}{A}$ — never as plain-text/unicode math ` +
    `(no "P/A", no "τ_ave"). Prose stays plain text; only the math itself goes inside $...$. ${languageNote} ` +
    `Return ONLY the JSON array matching the given schema, nothing else.`;

  const body = {
    contents: [
      {
        parts: [
          ...fileParts.map((f) => ({
            inline_data: { mime_type: f.mimeType, data: f.base64 },
          })),
          { text: prompt },
        ],
      },
    ],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: QUESTIONS_SCHEMA,
    },
  };

  // Gemini's shared free-tier capacity occasionally returns a transient
  // 503 "model overloaded" — retry a couple of times with backoff before
  // giving up, so a passing spike doesn't have to be a user-facing failure.
  const maxAttempts = 3;
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
    await new Promise((resolve) => setTimeout(resolve, attempt * 2000));
  }
  if (!res!.ok) {
    throw new Error(`Gemini API error: ${res!.status} ${await res!.text()}`);
  }
  const data = await res!.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("Gemini رجّع رد فاضي — جرّب تاني");

  let questions: unknown;
  try {
    questions = JSON.parse(text);
  } catch {
    throw new Error("Gemini رجّع JSON مش مكتوب صح");
  }
  if (!Array.isArray(questions) || questions.length === 0) {
    throw new Error("Gemini ما رجّعش أي أسئلة");
  }
  return questions;
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

    const {
      title,
      course_id,
      direction,
      files,
      drive_access_token,
    } = await req.json();

    if (!title || !Array.isArray(files) || files.length === 0) {
      return jsonResponse({ error: "بيانات ناقصة (title/files)" }, 400);
    }
    if (!drive_access_token) {
      return jsonResponse({ error: "مفيش توكن Drive" }, 400);
    }

    // Sequential, not Promise.all — fetching several files at once would
    // stack their peak memory footprints on top of each other right when
    // the worker is already tightest on resources.
    const fileParts: { base64: string; mimeType: string }[] = [];
    for (const f of files as { id: string; mime_type?: string | null }[]) {
      fileParts.push(await fetchFileAsPdf(f, drive_access_token));
    }

    const questions = await generateQuestions(
      fileParts,
      direction === "ltr" ? "ltr" : "rtl",
      geminiApiKey,
    );

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: { headers: { Authorization: authHeader } },
        auth: { persistSession: false, autoRefreshToken: false },
      },
    );

    const { data: quiz, error } = await supabase
      .from("quizzes")
      .insert({
        title,
        course_id: course_id ?? null,
        direction: direction === "ltr" ? "ltr" : "rtl",
        questions,
      })
      .select()
      .single();

    if (error) {
      return jsonResponse({ error: `فشل حفظ الاختبار: ${error.message}` }, 500);
    }

    return jsonResponse({ quiz });
  } catch (e) {
    return jsonResponse({ error: String(e instanceof Error ? e.message : e) }, 500);
  }
});
