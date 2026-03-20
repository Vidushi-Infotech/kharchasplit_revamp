import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../modules/onboarding/screens/onboarding_screen.dart';
import '../../modules/auth/screens/login_screen.dart';
import '../../modules/auth/screens/register_screen.dart';
import '../../modules/auth/screens/forgot_password_screen.dart';
import '../../modules/dashboard/screens/dashboard_screen.dart';
import '../../layouts/shell/mobile_shell.dart';
import '../../layouts/shell/tablet_shell.dart';
import '../../layouts/shell/web_shell.dart';

/// Go router configuration for the entire app
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // Auth routes (no shell)
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

    // Shell routes (responsive shell wrapper)
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
        // Dashboard
        GoRoute(
          path: '/home/dashboard',
          name: 'dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),

        // Groups
        GoRoute(
          path: '/home/groups',
          name: 'groups',
          builder: (context, state) => const Placeholder(),
        ),
        GoRoute(
          path: '/home/groups/:groupId',
          name: 'group-detail',
          builder: (context, state) {
            final groupId = state.pathParameters['groupId'];
            return Placeholder(child: Text('Group: $groupId'));
          },
        ),
        GoRoute(
          path: '/home/groups/:groupId/expenses/:expenseId',
          name: 'group-expense-detail',
          builder: (context, state) {
            final groupId = state.pathParameters['groupId'];
            final expenseId = state.pathParameters['expenseId'];
            return Placeholder(
              child: Text('Expense $expenseId in Group $groupId'),
            );
          },
        ),

        // Friends
        GoRoute(
          path: '/home/friends',
          name: 'friends',
          builder: (context, state) => const Placeholder(),
        ),
        GoRoute(
          path: '/home/friends/:friendId',
          name: 'friend-detail',
          builder: (context, state) {
            final friendId = state.pathParameters['friendId'];
            return Placeholder(child: Text('Friend: $friendId'));
          },
        ),

        // Activity
        GoRoute(
          path: '/home/activity',
          name: 'activity',
          builder: (context, state) => const Placeholder(),
        ),

        // Profile
        GoRoute(
          path: '/home/profile',
          name: 'profile',
          builder: (context, state) => const Placeholder(),
        ),
        GoRoute(
          path: '/home/profile/settings',
          name: 'settings',
          builder: (context, state) => const Placeholder(),
        ),
      ],
    ),

    // Modal routes (outside shell)
    GoRoute(
      path: '/add-expense',
      name: 'add-expense',
      builder: (context, state) => const Placeholder(),
    ),
    GoRoute(
      path: '/add-expense/:groupId',
      name: 'add-expense-to-group',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId'];
        return Placeholder(child: Text('Add expense to $groupId'));
      },
    ),
    GoRoute(
      path: '/settle/:userId',
      name: 'settle',
      builder: (context, state) {
        final userId = state.pathParameters['userId'];
        return Placeholder(child: Text('Settle with $userId'));
      },
    ),

    // Reports
    GoRoute(
      path: '/reports',
      name: 'reports',
      builder: (context, state) => const Placeholder(),
    ),
  ],
);
