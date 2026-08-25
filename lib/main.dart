import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'config/env/env.dart';
import 'core/network/supabase_client.dart';
import 'core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Env.load();
  await AppSupabase.initialize();
  tz_data.initializeTimeZones();
  // Without this, tz.local defaults to UTC and every scheduled reminder
  // fires at the wrong wall-clock time (off by the device's UTC offset).
  try {
    final deviceTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(deviceTimezone.identifier));
  } catch (_) {
    tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
  }
  await initializeDateFormatting('ar');
  await NotificationService.instance.init();

  runApp(const ProviderScope(child: StudyHubApp()));
}
