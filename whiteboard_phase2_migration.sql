-- Whiteboard Phase 2 (AI grading) — additive, idempotent migration.
-- Adds AI-grading columns to wb_submissions. No RLS/storage changes needed:
-- owners already have full access via owners_full_access, and the new
-- wb-grade Edge Function writes using the owner's own forwarded session.

alter table wb_submissions add column if not exists ai_score numeric;
alter table wb_submissions add column if not exists ai_max_score numeric;
alter table wb_submissions add column if not exists ai_feedback text;
alter table wb_submissions add column if not exists ai_graded_at timestamptz;

-- Privacy fix for the new live-checking feature: a student's device must
-- never be able to read model_answer/rubric/accepted_variations/checks —
-- only the wb-live-check/wb-grade Edge Functions read those (server-side,
-- via the service-role key). Anon previously had full-row SELECT on
-- wb_questions; restrict it to the columns the public board actually needs.
revoke select on wb_questions from anon;
grant select (
  id, teacher_id, subject_pack, prompt, source_path, source_type,
  reference_video_link, max_score, language, created_at
) on wb_questions to anon;
grant select on wb_questions to authenticated;
