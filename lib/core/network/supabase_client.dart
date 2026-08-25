import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/env/env.dart';

class AppSupabase {
  AppSupabase._();

  static Future<void> initialize() {
    return Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
