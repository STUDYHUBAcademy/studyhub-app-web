import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/supabase_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/sessions/presentation/providers/sessions_providers.dart';

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
    // Android pauses Dart timers while the app is backgrounded, so the
    // access token's usual proactive refresh (~1h before expiry) can miss
    // its window during a long stay in the background. Left alone, every
    // realtime subscription then fails with "Token has expired" as soon as
    // the app resumes, and every screen shows that raw error instead of its
    // data — so force a refresh right when the app comes back to front.
    if (state == AppLifecycleState.resumed) {
      _recoverSession();
    }
  }

  Future<void> _recoverSession() async {
    try {
      if (AppSupabase.client.auth.currentSession == null) return;
      await AppSupabase.client.auth.refreshSession();
    } catch (_) {
      // No valid refresh token left — the router's auth redirect will send
      // the owner back to /login on its own; nothing more to do here.
    }
    // A tab/app backgrounded for a while (switching to another app to grab
    // a link, leaving the browser tab in the background, etc.) can leave the
    // realtime socket a zombie: the heartbeat that's supposed to notice a
    // dead connection runs on a Dart Timer, which browsers/the OS throttle
    // or pause while backgrounded, so it may never fire the miss that would
    // trigger a reconnect. Every screen built on a `.stream()` then just
    // hangs with no error and no data. Force a clean reconnect the moment
    // we know we're back in the foreground instead of waiting for the
    // heartbeat to eventually catch up.
    try {
      await AppSupabase.client.realtime.disconnect();
      // The socket-level connect() call is package-internal, so force a
      // fresh connection the supported way: subscribing any channel makes
      // the client (re)open the shared socket, and every other channel that
      // was already joined rejoins automatically once it's back up.
      final pingChannel = AppSupabase.client.channel('resume-ping');
      pingChannel.subscribe();
      Future.delayed(const Duration(seconds: 3), () {
        AppSupabase.client.removeChannel(pingChannel);
      });
    } catch (_) {}
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
