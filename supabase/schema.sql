-- StudyHub Academy — initial schema
-- Run this once in the Supabase Dashboard: Project > SQL Editor > New query > paste > Run.
-- Safe to re-run: every statement is idempotent (IF NOT EXISTS / CREATE OR REPLACE).

create extension if not exists "pgcrypto";

-- ─────────────────────────────────────────────────────────────────────────
-- Helper: is the current request from one of the 2 owners?
-- ─────────────────────────────────────────────────────────────────────────
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  role text not null default 'owner' check (role = 'owner'),
  created_at timestamptz not null default now()
);

create or replace function is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid());
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Reference data
-- ─────────────────────────────────────────────────────────────────────────
create table if not exists universities (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists terms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  semester text check (semester in ('first','second','summer')),
  academic_year text,
  start_date date,
  end_date date,
  status text not null default 'upcoming' check (status in ('upcoming','active','closed')),
  created_at timestamptz not null default now()
);
alter table terms add column if not exists semester text;
alter table terms drop constraint if exists terms_semester_check;
alter table terms add constraint terms_semester_check check (semester in ('first','second','summer'));
alter table terms add column if not exists academic_year text;

-- ─────────────────────────────────────────────────────────────────────────
-- Tutor pipeline
-- ─────────────────────────────────────────────────────────────────────────
create table if not exists tutor_applications (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone_primary text,
  phone_whatsapp text,
  email text,
  demo_link text,
  graduation_faculty jsonb,
  subjects jsonb not null default '[]',
  status text not null default 'new' check (status in ('new','promoted','rejected')),
  submitted_at timestamptz not null default now()
);

create table if not exists tutors (
  id uuid primary key default gen_random_uuid(),
  application_id uuid references tutor_applications(id) on delete set null,
  name text not null,
  phone_primary text,
  phone_whatsapp text,
  email text,
  demo_link text,
  faculty jsonb,
  subjects jsonb not null default '[]',
  status text not null default 'active' check (status in ('active','inactive')),
  is_featured boolean not null default false,
  notes text,
  created_at timestamptz not null default now()
);
alter table tutors add column if not exists demo_link text;

-- 'featured' was briefly a third status value; it's now an independent flag
-- (is_featured) so a tutor can be active-and-featured or inactive-and-featured.
-- Migrate anything that used the old scheme, then tighten the constraint back.
alter table tutors add column if not exists is_featured boolean not null default false;
alter table tutors drop constraint if exists tutors_status_check;
update tutors set is_featured = true, status = 'active' where status = 'featured';
alter table tutors add constraint tutors_status_check check (status in ('active','inactive'));

-- One row per status change, so the app can show "active from X to Y" periods.
create table if not exists tutor_status_log (
  id uuid primary key default gen_random_uuid(),
  tutor_id uuid not null references tutors(id) on delete cascade,
  status text not null,
  changed_at timestamptz not null default now()
);

create or replace function log_tutor_status_change() returns trigger
language plpgsql as $$
begin
  if (tg_op = 'INSERT') then
    insert into tutor_status_log (tutor_id, status, changed_at) values (new.id, new.status, new.created_at);
  elsif (new.status is distinct from old.status) then
    insert into tutor_status_log (tutor_id, status, changed_at) values (new.id, new.status, now());
  end if;
  return new;
end;
$$;

drop trigger if exists trg_log_tutor_status_change on tutors;
create trigger trg_log_tutor_status_change
  after insert or update of status on tutors
  for each row execute function log_tutor_status_change();

-- Backfill log entries for tutors inserted before this trigger existed.
insert into tutor_status_log (tutor_id, status, changed_at)
select id, status, created_at from tutors t
where not exists (select 1 from tutor_status_log l where l.tutor_id = t.id);

create table if not exists subject_catalog_custom (
  id uuid primary key default gen_random_uuid(),
  dept_id text not null,
  ar text not null,
  en text not null,
  created_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────
-- Courses, demos, per-term pricing
-- ─────────────────────────────────────────────────────────────────────────
create table if not exists courses (
  id uuid primary key default gen_random_uuid(),
  subject_name text not null,
  university_id uuid references universities(id) on delete set null,
  tutor_id uuid references tutors(id) on delete set null,
  first_term_id uuid references terms(id) on delete set null,
  materials_link text,
  status text not null default 'planning' check (status in ('planning','active','inactive','archived')),
  created_at timestamptz not null default now()
);
alter table courses add column if not exists materials_link text;

-- 'demo' was a confusing course-level status (demos already have their own
-- section/table) — collapse it back into 'planning' and tighten the check.
update courses set status = 'planning' where status = 'demo';
alter table courses drop constraint if exists courses_status_check;
alter table courses add constraint courses_status_check check (status in ('planning','active','inactive','archived'));

create table if not exists course_demos (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references courses(id) on delete cascade,
  tutor_id uuid not null references tutors(id) on delete cascade,
  demo_at timestamptz,
  notes text,
  outcome text not null default 'pending' check (outcome in ('pending','selected','rejected')),
  created_at timestamptz not null default now()
);

create table if not exists course_terms (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references courses(id) on delete cascade,
  term_id uuid not null references terms(id) on delete cascade,
  pricing_model text not null default 'flat' check (pricing_model in ('flat','revshare')),
  tutor_flat_fee numeric,
  tutor_flat_fee_currency text default 'EGP',
  revshare_pct numeric default 10,
  student_price numeric,
  student_price_currency text default 'SAR',
  status text not null default 'planning' check (status in ('planning','marketing','active','completed','cancelled')),
  created_at timestamptz not null default now(),
  unique (course_id, term_id)
);

-- ─────────────────────────────────────────────────────────────────────────
-- Students & enrollments
-- ─────────────────────────────────────────────────────────────────────────
create table if not exists students (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone_whatsapp text,
  university_id uuid references universities(id) on delete set null,
  created_at timestamptz not null default now()
);

-- How the student found the academy — drives commission owed to a referral
-- channel. 'haraj' is always 1% (fixed listing-site fee); 'marketer' carries
-- a per-student negotiated percentage set at registration time.
alter table students add column if not exists acquisition_source text not null default 'direct';
alter table students drop constraint if exists students_acquisition_source_check;
alter table students add constraint students_acquisition_source_check check (acquisition_source in ('direct','haraj','marketer'));
alter table students add column if not exists marketer_name text;
alter table students add column if not exists commission_pct numeric;

create table if not exists enrollments (
  id uuid primary key default gen_random_uuid(),
  course_term_id uuid not null references course_terms(id) on delete cascade,
  student_id uuid not null references students(id) on delete cascade,
  amount numeric not null default 0,
  currency text not null default 'SAR',
  payment_status text not null default 'pending' check (payment_status in ('pending','paid','overdue')),
  payment_method text not null default 'cash' check (payment_method in ('cash','visa','tabby','tamara')),
  joined_at timestamptz not null default now()
);
alter table enrollments add column if not exists payment_method text not null default 'cash';
alter table enrollments drop constraint if exists enrollments_payment_method_check;
alter table enrollments add constraint enrollments_payment_method_check check (payment_method in ('cash','visa','tabby','tamara'));
-- 'partial' covers an enrollment with some but not all installments paid —
-- the exact amount paid/remaining is derived from enrollment_payments below.
alter table enrollments drop constraint if exists enrollments_payment_status_check;
alter table enrollments add constraint enrollments_payment_status_check check (payment_status in ('pending','partial','paid','overdue'));
-- A cancelled enrollment stops counting toward expected/owed revenue (only
-- what was actually paid before cancelling still counts) but stays in the
-- list so it can be reactivated if the student comes back.
alter table enrollments add column if not exists status text not null default 'active';
alter table enrollments drop constraint if exists enrollments_status_check;
alter table enrollments add constraint enrollments_status_check check (status in ('active','cancelled'));
-- A permanent reduction of what's actually owed — a discount given to the
-- student, or a payment-gateway cut (Tabby/Tamara/Visa) that the academy
-- never sees. Effective amount owed = amount - write_off_amount, so the
-- "remaining" balance can be zeroed out without pretending the gap was paid.
alter table enrollments add column if not exists write_off_amount numeric not null default 0;
alter table enrollments add column if not exists write_off_reason text;
-- Per-enrollment acquisition source override — the same student can come via
-- a marketer for one course and directly for another, so this can't live
-- only on students. Null means "inherit the student's own default".
alter table enrollments add column if not exists acquisition_source text;
alter table enrollments drop constraint if exists enrollments_acquisition_source_check;
alter table enrollments add constraint enrollments_acquisition_source_check check (acquisition_source is null or acquisition_source in ('direct','haraj','marketer'));
alter table enrollments add column if not exists marketer_name text;
alter table enrollments add column if not exists commission_pct numeric;

-- One row per installment received against a course enrollment, so a
-- student's fee can be paid across multiple visits/dates instead of forcing
-- a single all-or-nothing payment.
create table if not exists enrollment_payments (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references enrollments(id) on delete cascade,
  amount numeric not null,
  currency text not null default 'SAR',
  payment_method text not null default 'cash' check (payment_method in ('cash','visa','tabby','tamara')),
  paid_at date not null default current_date,
  notes text,
  created_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────
-- Private 1:1 sessions (WhatsApp-arranged)
-- ─────────────────────────────────────────────────────────────────────────
create table if not exists private_sessions (
  id uuid primary key default gen_random_uuid(),
  tutor_id uuid references tutors(id) on delete set null,
  student_id uuid references students(id) on delete set null,
  subject text not null,
  scheduled_at timestamptz,
  duration_minutes integer not null default 60,
  hourly_rate numeric,
  currency text not null default 'EGP',
  student_hourly_rate numeric,
  student_total numeric,
  student_total_currency text not null default 'SAR',
  student_amount_received numeric,
  payment_method text not null default 'cash' check (payment_method in ('cash','visa','tabby','tamara')),
  tutor_hourly_rate numeric,
  tutor_payout numeric,
  tutor_payout_currency text not null default 'EGP',
  margin numeric,
  status text not null default 'scheduled' check (status in ('scheduled','completed','cancelled')),
  student_paid boolean not null default false,
  tutor_paid boolean not null default false,
  material_note text,
  created_by uuid references profiles(id),
  created_at timestamptz not null default now()
);
alter table private_sessions alter column scheduled_at drop not null;
alter table private_sessions add column if not exists student_total_currency text not null default 'SAR';
alter table private_sessions add column if not exists tutor_payout_currency text not null default 'EGP';
alter table private_sessions add column if not exists student_hourly_rate numeric;
alter table private_sessions add column if not exists tutor_hourly_rate numeric;
alter table private_sessions add column if not exists student_amount_received numeric;
alter table private_sessions add column if not exists payment_method text not null default 'cash';
alter table private_sessions drop constraint if exists private_sessions_payment_method_check;
alter table private_sessions add constraint private_sessions_payment_method_check check (payment_method in ('cash','visa','tabby','tamara'));
-- Set by the send-session-reminders Edge Function once it's WhatsApp'd the
-- tutor/owners for a session, so the cron job doesn't message twice.
alter table private_sessions add column if not exists whatsapp_reminder_sent boolean not null default false;
-- A permanent reduction of what's actually owed — a discount given to the
-- student, or a payment-gateway cut the academy never sees. Mirrors the same
-- concept on enrollments so courses and private sessions behave the same way.
alter table private_sessions add column if not exists write_off_amount numeric not null default 0;
alter table private_sessions add column if not exists write_off_reason text;
-- Per-session acquisition source override — same reasoning as enrollments:
-- null means "inherit the student's own default".
alter table private_sessions add column if not exists acquisition_source text;
alter table private_sessions drop constraint if exists private_sessions_acquisition_source_check;
alter table private_sessions add constraint private_sessions_acquisition_source_check check (acquisition_source is null or acquisition_source in ('direct','haraj','marketer'));
alter table private_sessions add column if not exists marketer_name text;
alter table private_sessions add column if not exists commission_pct numeric;

-- ─────────────────────────────────────────────────────────────────────────
-- Tutor ledger (deposits / payouts / revshare settlements)
-- ─────────────────────────────────────────────────────────────────────────
create table if not exists tutor_ledger (
  id uuid primary key default gen_random_uuid(),
  tutor_id uuid not null references tutors(id) on delete cascade,
  course_term_id uuid references course_terms(id) on delete set null,
  private_session_id uuid references private_sessions(id) on delete set null,
  amount numeric not null,
  currency text not null default 'EGP',
  equivalent_sar_amount numeric,
  type text not null check (type in ('deposit','final_settlement','revshare_payout','private_session_payout')),
  date date not null default current_date,
  notes text,
  created_at timestamptz not null default now()
);
alter table tutor_ledger add column if not exists equivalent_sar_amount numeric;
alter table tutor_ledger add column if not exists private_session_id uuid references private_sessions(id) on delete set null;

-- ─────────────────────────────────────────────────────────────────────────
-- Academy operating expenses (admin, ads, hosting, software subscriptions...)
-- ─────────────────────────────────────────────────────────────────────────
create table if not exists academy_expenses (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in ('admin','ads','subscriptions','other')),
  name text not null,
  amount numeric not null,
  currency text not null default 'SAR',
  date date not null default current_date,
  notes text,
  created_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────
-- Owner (partner) withdrawals — cash either owner takes out of the academy's
-- balance before term-end settlement. No term scoping: the dashboard is
-- always a cumulative running balance, so unwithdrawn profit naturally
-- carries forward into the next term on its own.
-- ─────────────────────────────────────────────────────────────────────────
create table if not exists owner_withdrawals (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  amount numeric not null,
  currency text not null default 'SAR',
  date date not null default current_date,
  notes text,
  created_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────
-- Cash flow
-- ─────────────────────────────────────────────────────────────────────────
create table if not exists transactions (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('income','expense')),
  category text not null,
  amount numeric not null,
  currency text not null default 'EGP',
  related_course_term_id uuid references course_terms(id) on delete set null,
  related_tutor_id uuid references tutors(id) on delete set null,
  related_session_id uuid references private_sessions(id) on delete set null,
  status text not null default 'received' check (status in ('received','pending','overdue')),
  date date not null default current_date,
  notes text,
  auto_generated boolean not null default false,
  created_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────
-- Tasks / notes
-- ─────────────────────────────────────────────────────────────────────────
create table if not exists tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text,
  due_date date,
  status text not null default 'open' check (status in ('open','done')),
  linked_course_id uuid references courses(id) on delete set null,
  created_by uuid references profiles(id),
  progress_note text,
  created_at timestamptz not null default now()
);
alter table tasks add column if not exists progress_note text;

-- ─────────────────────────────────────────────────────────────────────────
-- Chat (one channel per course, plus one general channel)
-- ─────────────────────────────────────────────────────────────────────────
create table if not exists chat_channels (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('course','general')),
  course_id uuid unique references courses(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists chat_messages (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references chat_channels(id) on delete cascade,
  sender_id uuid references profiles(id),
  body text,
  attachment_url text,
  created_at timestamptz not null default now()
);

-- Auto-create a chat channel whenever a course is created.
create or replace function create_course_chat_channel() returns trigger
language plpgsql as $$
begin
  insert into chat_channels (type, course_id, name)
  values ('course', new.id, new.subject_name)
  on conflict (course_id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_create_course_chat_channel on courses;
create trigger trg_create_course_chat_channel
  after insert on courses
  for each row execute function create_course_chat_channel();

-- Seed the one general channel (idempotent).
insert into chat_channels (type, name)
select 'general', 'عام'
where not exists (select 1 from chat_channels where type = 'general');

-- ─────────────────────────────────────────────────────────────────────────
-- Row Level Security
-- Every table: the 2 owners get full access. tutor_applications additionally
-- allows anonymous INSERT only (the public tutor registration form).
-- ─────────────────────────────────────────────────────────────────────────
do $$
declare
  t text;
  owner_tables text[] := array[
    'profiles','universities','terms','tutors','tutor_status_log','subject_catalog_custom',
    'courses','course_demos','course_terms','students','enrollments','enrollment_payments',
    'tutor_ledger','private_sessions','transactions','tasks','academy_expenses','owner_withdrawals',
    'chat_channels','chat_messages','tutor_applications'
  ];
begin
  foreach t in array owner_tables loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists owners_full_access on %I', t);
    execute format(
      'create policy owners_full_access on %I for all using (is_owner()) with check (is_owner())',
      t
    );
  end loop;
end $$;

-- Public tutor registration form: anyone can submit an application, no read/update/delete.
-- Scoped "to public" (any role) rather than "to anon" — Supabase's newer
-- publishable/secret key gateway doesn't always switch the session to the
-- literal `anon` Postgres role, so a `to anon` policy can silently never
-- match. `to public` sidesteps that while `is_owner()` still gates the
-- owners-only policy above.
drop policy if exists public_can_apply on tutor_applications;
create policy public_can_apply on tutor_applications
  for insert
  to public
  with check (true);
grant insert on tutor_applications to anon, authenticated;

-- Public can also read/add to the shared subject catalog (needed by the form's
-- "add your own subject" flow), but never delete from it.
drop policy if exists public_can_read_catalog on subject_catalog_custom;
create policy public_can_read_catalog on subject_catalog_custom
  for select
  to public
  using (true);

drop policy if exists public_can_add_catalog on subject_catalog_custom;
create policy public_can_add_catalog on subject_catalog_custom
  for insert
  to public
  with check (true);
grant select, insert on subject_catalog_custom to anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- Storage buckets
-- ─────────────────────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public)
values
  ('tutor-demos', 'tutor-demos', false),
  ('session-materials', 'session-materials', false),
  ('chat-attachments', 'chat-attachments', false)
on conflict (id) do nothing;

drop policy if exists owners_storage_access on storage.objects;
create policy owners_storage_access on storage.objects
  for all
  using (bucket_id in ('tutor-demos','session-materials','chat-attachments') and is_owner())
  with check (bucket_id in ('tutor-demos','session-materials','chat-attachments') and is_owner());

-- Realtime: every table the app subscribes to via .stream() must be in this
-- publication, or the subscription errors out client-side. Cover all
-- owner-facing tables now rather than adding them one phase at a time.
-- (ALTER PUBLICATION ... ADD TABLE has no IF NOT EXISTS, so guard it manually.)
do $$
declare
  t text;
  realtime_tables text[] := array[
    'tutor_applications','tutors','universities','terms',
    'courses','course_demos','course_terms','students','enrollments','enrollment_payments',
    'tutor_ledger','private_sessions','transactions','tasks','academy_expenses','owner_withdrawals',
    'chat_channels','chat_messages'
  ];
begin
  foreach t in array realtime_tables loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table %I', t);
    end if;
  end loop;
end $$;
