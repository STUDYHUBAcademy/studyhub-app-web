import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/supabase_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/activity_log/presentation/providers/activity_log_providers.dart';
import 'features/courses/presentation/providers/courses_providers.dart';
import 'features/finance/presentation/providers/finance_providers.dart';
import 'features/marketers/presentation/providers/marketers_providers.dart';
import 'features/sessions/presentation/providers/sessions_providers.dart';
import 'features/settings/presentation/providers/app_settings_providers.dart';
import 'features/students/presentation/providers/students_providers.dart';
import 'features/tasks/presentation/providers/tasks_providers.dart';
import 'features/tutors/presentation/providers/tutors_providers.dart';
import 'features/universities/presentation/providers/universities_providers.dart';

class StudyHubApp extends ConsumerStatefulWidget {
  const StudyHubApp({super.key});

  @override
  ConsumerState<StudyHubApp> createState() => _StudyHubAppState();
}

class _StudyHubAppState extends ConsumerState<StudyHubApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recoverSession();
    }
  }

  Future<void> _recoverSession() async {
    try {
      if (AppSupabase.client.auth.currentSession == null) return;
      await AppSupabase.client.auth.refreshSession();
    } catch (_) {}

    if (mounted) {
      ref.invalidate(coursesProvider);
      ref.invalidate(allEnrollmentsProvider);
      ref.invalidate(studentsProvider);
      ref.invalidate(tutorsProvider);
      ref.invalidate(applicationsProvider);
      ref.invalidate(sessionsProvider);
      ref.invalidate(expensesProvider);
      ref.invalidate(withdrawalsProvider);
      ref.invalidate(ownerProfilesProvider);
      ref.invalidate(tasksProvider);
      ref.invalidate(marketersProvider);
      ref.invalidate(universitiesProvider);
      ref.invalidate(termsProvider);
      ref.invalidate(activityLogProvider);
      ref.invalidate(appSettingsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionsReminderSyncProvider);
    return MaterialApp.router(
      title: 'StudyHub Academy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // The dense card/chip layouts throughout this app assume roughly
        // the platform-default text size. Left unclamped, a device with a
        // large system font/display-size setting scales text (and the
        // glyph-based Icons that share its font size) enough to overflow
        // those layouts — clamp to a range that still respects the user's
        // preference without breaking the UI.
        final scaler = MediaQuery.textScalerOf(context)
            .clamp(minScaleFactor: 0.85, maxScaleFactor: 1.2);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: child!,
        );
      },
    );
  }
}
