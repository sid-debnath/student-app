import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_details_screen.dart';
import '../features/announcements/announcements_screen.dart';
import '../features/attendance/attendance_screen.dart';
import '../features/auth/change_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/home/dashboard_screen.dart';
import '../features/home/home_shell.dart';
import '../features/home/more_screen.dart';
import '../features/homework/homework_screen.dart';
import '../features/marks/marks_screen.dart';
import '../features/ptm/ptm_screen.dart';
import '../features/roster/roster_screen.dart';
import '../features/roster/users_screen.dart';
import '../features/timetable/timetable_screen.dart';
import 'providers.dart';
import 'refresh_stream.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = GoRouterRefreshStream(
    ref.watch(authRepositoryProvider).authState(),
  );
  ref.listen(sessionProvider, (_, _) => refresh.notifyListeners());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';
      final auth = ref.read(authUserProvider);
      if (auth.isLoading) return null;
      final user = auth.valueOrNull;
      if (user == null) {
        return loggingIn ? null : '/login';
      }
      final session = ref.read(sessionProvider);
      if (session.isLoading) return null;
      final profile = session.valueOrNull;
      if (profile == null) {
        return loggingIn ? null : '/login';
      }
      final changingPassword = state.matchedLocation == '/change-password';
      if (profile.requiresFirstLoginPasswordChange) {
        return changingPassword ? null : '/change-password';
      }
      if (loggingIn || changingPassword) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/roster', builder: (context, state) => const RosterScreen()),
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const AttendanceScreen(),
          ),
          GoRoute(
            path: '/homework',
            builder: (context, state) => const HomeworkScreen(),
          ),
          GoRoute(
            path: '/announcements',
            builder: (context, state) => const AnnouncementsScreen(),
          ),
          GoRoute(path: '/more', builder: (context, state) => const MoreScreen()),
          GoRoute(
            path: '/account',
            builder: (context, state) => const AccountDetailsScreen(),
          ),
          GoRoute(path: '/users', builder: (context, state) => const UsersScreen()),
          GoRoute(
            path: '/timetable',
            builder: (context, state) => const TimetableScreen(),
          ),
          GoRoute(path: '/marks', builder: (context, state) => const MarksScreen()),
          GoRoute(path: '/ptm', builder: (context, state) => const PtmScreen()),
        ],
      ),
    ],
  );
});
