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

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

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
  const mimeType = isGoogleNative
    ? "application/pdf"
    : file.mime_type || "application/pdf";
  return { base64: bytesToBase64(bytes), mimeType };
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
    `Produce between 10 and 20 questions covering the material's key concepts (not trivial trivia). ` +
    `Each question needs exactly 4 plausible options and a 0-based correct_index. ` +
    `Set "topic" to a short label for the section/concept the question covers (used to group weak-area feedback) — ` +
    `reuse the same topic label for multiple questions from the same section. ${languageNote} ` +
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

    const fileParts = await Promise.all(
      files.map((f: { id: string; mime_type?: string | null }) =>
        fetchFileAsPdf(f, drive_access_token)
      ),
    );

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
