-- Whiteboard "free study mode" — additive, idempotent migration.
--
-- Lets any student open a public canvas, pick one of the academy's courses,
-- and get live AI-checked practice (no assignment, no teacher-authored
-- question). The AI is grounded in a cached digest of that course's Drive
-- material, built once by the owner (via "تحديث قاعدة المعرفة" on the
-- course screen) and reused for every future check — a public/anonymous
-- student has no Google sign-in of their own to read Drive with live.

create table if not exists course_knowledge (
  course_id uuid primary key references courses(id) on delete cascade,
  summary text not null,
  file_names text[] not null default '{}',
  updated_at timestamptz not null default now()
);
alter table course_knowledge enable row level security;
drop policy if exists owners_full_access on course_knowledge;
create policy owners_full_access on course_knowledge
  for all using (is_owner()) with check (is_owner());

-- Public course picker for /study: subject names only, never pricing,
-- tutor assignment, or any other course-detail column.
drop policy if exists public_can_read_active_courses on courses;
create policy public_can_read_active_courses on courses
  for select
  to public
  using (status = 'active');
grant select (id, subject_name) on courses to anon;
