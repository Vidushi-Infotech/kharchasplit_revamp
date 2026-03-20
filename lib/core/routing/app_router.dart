import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../modules/onboarding/screens/onboarding_screen.dart';
import '../../modules/auth/screens/login_screen.dart';
import '../../modules/auth/screens/register_screen.dart';
import '../../modules/auth/screens/forgot_password_screen.dart';
import '../../modules/dashboard/screens/dashboard_screen.dart';
import '../../modules/groups/screens/groups_screen.dart';
import '../../modules/friends/screens/friends_screen.dart';
import '../../modules/activity/screens/activity_screen.dart';
import '../../modules/profile/screens/profile_screen.dart';
import '../../layouts/shell/mobile_shell.dart';
import '../../layouts/shell/tablet_shell.dart';
import '../../layouts/shell/web_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      name: 'forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        if (screenWidth < 600) {
          return MobileShell(child: child);
        } else if (screenWidth < 1100) {
          return TabletShell(child: child);
        } else {
          return WebShell(child: child);
        }
      },
      routes: [
        GoRoute(
          path: '/home/dashboard',
          name: 'dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/home/groups',
          name: 'groups',
          builder: (context, state) => const GroupsScreen(),
        ),
        GoRoute(
          path: '/home/groups/:groupId',
          name: 'group-detail',
          builder: (context, state) {
            final groupId = state.pathParameters['groupId'];
            return Scaffold(
              appBar: AppBar(title: Text('Group: $groupId')),
              body: Center(child: Text('Group Detail: $groupId')),
            );
          },
        ),
        GoRoute(
          path: '/home/friends',
          name: 'friends',
          builder: (context, state) => const FriendsScreen(),
        ),
        GoRoute(
          path: '/home/activity',
          name: 'activity',
          builder: (context, state) => const ActivityScreen(),
        ),
        GoRoute(
          path: '/home/profile',
          name: 'profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/home/profile/settings',
          name: 'settings',
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: const Center(child: Text('Settings')),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/add-expense',
      name: 'add-expense',
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Add Expense')),
        body: const Center(child: Text('Add Expense')),
      ),
    ),
    GoRoute(
      path: '/reports',
      name: 'reports',
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Reports')),
        body: const Center(child: Text('Reports')),
      ),
    ),
  ],
);
