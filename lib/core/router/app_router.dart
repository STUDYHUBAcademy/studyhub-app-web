import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/courses/presentation/screens/course_detail_screen.dart';
import '../../features/courses/presentation/screens/courses_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/finance/presentation/screens/finance_screen.dart';
import '../../features/settings/presentation/screens/more_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/sessions/presentation/screens/sessions_screen.dart';
import '../../features/students/presentation/screens/students_screen.dart';
import '../../features/tasks/presentation/screens/tasks_screen.dart';
import '../../features/tutors/presentation/screens/tutor_detail_screen.dart';
import '../../features/tutors/presentation/screens/tutors_screen.dart';
import '../../features/universities/presentation/screens/universities_terms_screen.dart';
import '../network/supabase_client.dart';
import 'app_shell.dart';
import 'go_router_refresh_stream.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  refreshListenable: GoRouterRefreshStream(
    AppSupabase.client.auth.onAuthStateChange,
  ),
  redirect: (context, state) {
    final signedIn = AppSupabase.client.auth.currentSession != null;
    final onLogin = state.matchedLocation == '/login';

    if (!signedIn && !onLogin) return '/login';
    if (signedIn && onLogin) return '/dashboard';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

    // Top-level pages pushed from the "More" tab.
    GoRoute(
      path: '/finance',
      builder: (context, state) => const FinanceScreen(),
    ),
    GoRoute(
      path: '/students',
      builder: (context, state) => const StudentsScreen(),
    ),
    GoRoute(path: '/chat', builder: (context, state) => const ChatListScreen()),
    GoRoute(path: '/tasks', builder: (context, state) => const TasksScreen()),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/tutors/:id',
      builder: (context, state) =>
          TutorDetailScreen(tutorId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/courses/:id',
      builder: (context, state) =>
          CourseDetailScreen(courseId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/universities',
      builder: (context, state) => const UniversitiesTermsScreen(),
    ),

    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/courses',
              builder: (context, state) => const CoursesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/tutors',
              builder: (context, state) => const TutorsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/sessions',
              builder: (context, state) => const SessionsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/more',
              builder: (context, state) => const MoreScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
