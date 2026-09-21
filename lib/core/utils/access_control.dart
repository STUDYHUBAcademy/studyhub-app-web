import '../network/supabase_client.dart';

/// The account tutor contact details (phone/WhatsApp/email) are hidden from.
const _restrictedTutorContactsEmail = 'studyhub.ksa@gmail.com';

/// Whether the signed-in owner is allowed to see tutors' phone/WhatsApp/email.
bool get canViewTutorContacts =>
    AppSupabase.client.auth.currentUser?.email != _restrictedTutorContactsEmail;
