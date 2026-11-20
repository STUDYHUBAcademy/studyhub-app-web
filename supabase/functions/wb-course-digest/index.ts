// Supabase Edge Function: wb-course-digest
//
// Owner-triggered (from the course screen's "تحديث قاعدة المعرفة" button):
// reads the Drive files the owner picks for a course, asks Gemini to
// condense them into a compact reference a tutor would use to grade work,
// and caches that summary in course_knowledge. This is what makes the
// public free-study canvas (/study) "strong" per course — a public/
// anonymous student has no Google sign-in of their own to read Drive with
// live, so the digest is built once (by the owner, who does have Drive
// access) and reused by every future check for that course.
//
// Deploy: paste this file's contents into
//   Supabase Dashboard -> Edge Functions -> wb-course-digest -> Code
// (or `supabase functions deploy wb-course-digest` if you have the CLI).
// No new secret needed: reuses the "QUIZ" Gemini key.

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
const MAX_FILE_BYTES = 12 * 1024 * 1024; // 12MB — same ceiling as generate-quiz

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

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
      } ميجا.`,
    );
  }
  const mimeType = isGoogleNative
    ? "application/pdf"
    : file.mime_type || "application/pdf";
  return { base64: encodeBase64(bytes), mimeType };
}

async function digest(
  fileParts: { base64: string; mimeType: string }[],
  subjectName: string,
  geminiApiKey: string,
): Promise<string> {
  const prompt =
    `You are preparing reference notes for a tutor who will grade students' handwritten work in the course ` +
    `"${subjectName}", based on the attached course material (lecture slides, notes, past problems, etc.). ` +
    `Write a dense, well-organized reference covering: the key topics/chapters covered, the standard notation and ` +
    `conventions this specific course uses, important formulas, the typical worked-example method shown for each ` +
    `topic type, and any unusual grading conventions evident from the material (e.g. sign conventions, required ` +
    `units, specific solution format). Write it as plain prose/bullet points the tutor will read before grading — ` +
    `not a summary for a student. Keep it information-dense; aim for roughly 800-1500 words depending on how much ` +
    `the material actually covers. Write in the same language as the material. Return ONLY the reference text, ` +
    `no preamble.`;

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
  };

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
    throw new Error(`Gemini API error (${res!.status}): ${await res!.text()}`);
  }
  const data = await res!.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("Gemini رجّع رد فاضي — جرّب تاني");
  return text as string;
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

    const { course_id, files, drive_access_token } = await req.json();
    if (!course_id || !Array.isArray(files) || files.length === 0) {
      return jsonResponse({ error: "بيانات ناقصة (course_id/files)" }, 400);
    }
    if (!drive_access_token) {
      return jsonResponse({ error: "مفيش توكن Drive" }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: { headers: { Authorization: authHeader } },
        auth: { persistSession: false, autoRefreshToken: false },
      },
    );

    const { data: course, error: courseError } = await supabase
      .from("courses")
      .select("id, subject_name")
      .eq("id", course_id)
      .single();
    if (courseError || !course) {
      return jsonResponse({ error: "الكورس غير موجود" }, 404);
    }

    const fileParts: { base64: string; mimeType: string }[] = [];
    for (const f of files as { id: string; mime_type?: string | null }[]) {
      fileParts.push(await fetchFileAsPdf(f, drive_access_token));
    }

    const summary = await digest(fileParts, course.subject_name, geminiApiKey);
    const fileNames = (files as { name?: string }[])
      .map((f) => f.name)
      .filter((n): n is string => !!n);

    const { error: upsertError } = await supabase
      .from("course_knowledge")
      .upsert({
        course_id,
        summary,
        file_names: fileNames,
        updated_at: new Date().toISOString(),
      });
    if (upsertError) {
      return jsonResponse(
        { error: `فشل حفظ قاعدة المعرفة: ${upsertError.message}` },
        500,
      );
    }

    return jsonResponse({ summary, updated_at: new Date().toISOString() });
  } catch (e) {
    return jsonResponse(
      { error: String(e instanceof Error ? e.message : e) },
      500,
    );
  }
});
