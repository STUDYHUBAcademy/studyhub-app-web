-- Adds a per-course Telegram channel link, alongside the existing Drive
-- materials link, shown on the course screen.
--
-- Note: this only STORES the link for reference — the AI course-grounding
-- (course_knowledge digest) still only reads the Drive material, since
-- reading actual Telegram channel content would need a separate Telegram
-- Bot API integration, not built yet.
alter table courses add column if not exists telegram_link text;
