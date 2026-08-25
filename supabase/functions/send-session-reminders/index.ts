// Sends an automatic WhatsApp reminder (via WhatsApp Business Cloud API) to
// the tutor and both owners for any private session starting in ~5-9
// minutes. Meant to be invoked every few minutes by a pg_cron job (see
// supabase/schema.sql for the cron setup).
//
// Required secrets (set via Supabase Dashboard > Edge Functions > Manage secrets,
// or `supabase secrets set`):
//   WHATSAPP_ACCESS_TOKEN     - permanent access token from Meta
//   WHATSAPP_PHONE_NUMBER_ID  - the sending number's phone_number_id
//   WHATSAPP_TEMPLATE_NAME    - approved template name (default: session_reminder)
//   OWNER_WHATSAPP_NUMBERS    - comma-separated owner numbers, e.g. "201234567890,966512345678"
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically by the platform.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const WHATSAPP_TOKEN = Deno.env.get('WHATSAPP_ACCESS_TOKEN')!;
const WHATSAPP_PHONE_NUMBER_ID = Deno.env.get('WHATSAPP_PHONE_NUMBER_ID')!;
const WHATSAPP_TEMPLATE_NAME = Deno.env.get('WHATSAPP_TEMPLATE_NAME') ?? 'session_reminder';
const OWNER_WHATSAPP_NUMBERS = (Deno.env.get('OWNER_WHATSAPP_NUMBERS') ?? '')
  .split(',')
  .map((n) => n.trim())
  .filter(Boolean);

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

// Mirrors lib/core/utils/contact_links.dart's toWhatsappNumber().
function toWhatsappNumber(raw: string): string {
  let n = raw.replace(/[^\d+]/g, '');
  if (n.startsWith('+')) return n.slice(1);
  if (n.startsWith('00')) return n.slice(2);
  if (n.startsWith('0')) return '20' + n.slice(1);
  return n;
}

async function sendWhatsapp(to: string, subject: string, when: string): Promise<boolean> {
  const res = await fetch(`https://graph.facebook.com/v22.0/${WHATSAPP_PHONE_NUMBER_ID}/messages`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${WHATSAPP_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      messaging_product: 'whatsapp',
      to,
      type: 'template',
      template: {
        name: WHATSAPP_TEMPLATE_NAME,
        language: { code: 'ar' },
        components: [
          {
            type: 'body',
            parameters: [
              { type: 'text', text: subject },
              { type: 'text', text: when },
            ],
          },
        ],
      },
    }),
  });
  if (!res.ok) {
    console.error('WhatsApp send failed', await res.text());
  }
  return res.ok;
}

Deno.serve(async () => {
  const now = Date.now();
  const windowStart = new Date(now + 4 * 60 * 1000).toISOString();
  const windowEnd = new Date(now + 9 * 60 * 1000).toISOString();

  const { data: sessions, error } = await supabase
    .from('private_sessions')
    .select('id, subject, scheduled_at, tutors ( phone_whatsapp )')
    .eq('status', 'scheduled')
    .eq('whatsapp_reminder_sent', false)
    .gte('scheduled_at', windowStart)
    .lte('scheduled_at', windowEnd);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  let sent = 0;
  for (const s of sessions ?? []) {
    const when = new Intl.DateTimeFormat('ar-SA', { dateStyle: 'medium', timeStyle: 'short' }).format(
      new Date(s.scheduled_at),
    );

    const recipients = [...OWNER_WHATSAPP_NUMBERS];
    const tutorPhone = (s as { tutors?: { phone_whatsapp?: string } }).tutors?.phone_whatsapp;
    if (tutorPhone) recipients.push(tutorPhone);

    let anySent = false;
    for (const phone of recipients) {
      const ok = await sendWhatsapp(toWhatsappNumber(phone), s.subject, when);
      anySent ||= ok;
    }

    if (anySent) {
      await supabase.from('private_sessions').update({ whatsapp_reminder_sent: true }).eq('id', s.id);
      sent++;
    }
  }

  return new Response(JSON.stringify({ checked: sessions?.length ?? 0, sent }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
