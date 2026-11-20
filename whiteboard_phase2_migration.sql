-- Whiteboard Phase 2 (AI grading) — additive, idempotent migration.
-- Adds AI-grading columns to wb_submissions. No RLS/storage changes needed:
-- owners already have full access via owners_full_access, and the new
-- wb-grade Edge Function writes using the owner's own forwarded session.

alter table wb_submissions add column if not exists ai_score numeric;
alter table wb_submissions add column if not exists ai_max_score numeric;
alter table wb_submissions add column if not exists ai_feedback text;
alter table wb_submissions add column if not exists ai_graded_at timestamptz;
