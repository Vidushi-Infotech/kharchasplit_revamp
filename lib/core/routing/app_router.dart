import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../modules/onboarding/screens/onboarding_screen.dart';
import '../../modules/auth/screens/login_screen.dart';
import '../../modules/auth/screens/otp_verification_screen.dart';
import '../../modules/auth/screens/register_screen.dart';
import '../../modules/auth/screens/forgot_password_screen.dart';
import '../../modules/dashboard/screens/dashboard_screen.dart';
import '../../modules/dashboard/screens/owed_to_me_screen.dart';
import '../../modules/dashboard/screens/i_owe_screen.dart';
import '../../modules/groups/screens/groups_screen.dart';
import '../../modules/groups/screens/group_detail_screen.dart';
import '../../modules/groups/screens/create_group_screen.dart';
import '../../modules/friends/screens/friends_screen.dart';
import '../../modules/friends/screens/friend_detail_screen.dart';
import '../../modules/activity/screens/activity_screen.dart';
import '../../modules/profile/screens/profile_screen.dart';
import '../../modules/expenses/screens/add_expense_screen.dart';
import '../../modules/expenses/screens/expense_detail_screen.dart';
import '../../modules/reports/screens/reports_screen.dart';
import '../../modules/settlements/screens/settle_screen.dart';
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
      path: '/verify-otp',
      name: 'verify-otp',
      builder: (context, state) {
        final phone = state.uri.queryParameters['phone'] ?? '';
        return OtpVerificationScreen(phone: phone);
      },
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
          path: '/home/friends',
          name: 'friends',
          builder: (context, state) => const FriendsScreen(),
        ),
        GoRoute(
          path: '/home/activity',
          name: 'activity',
          builder: (context, state) => const ActivityScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/home/owed-to-me',
      name: 'owed-to-me',
      builder: (context, state) => const OwedToMeScreen(),
    ),
    GoRoute(
      path: '/home/i-owe',
      name: 'i-owe',
      builder: (context, state) => const IOweScreen(),
    ),
    GoRoute(
      path: '/home/groups/:groupId',
      name: 'group-detail',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        return GroupDetailScreen(groupId: groupId);
      },
    ),
    GoRoute(
      path: '/home/create-group',
      name: 'create-group',
      builder: (context, state) => const CreateGroupScreen(),
    ),
    GoRoute(
      path: '/home/friends/:friendId',
      name: 'friend-detail',
      builder: (context, state) {
        final friendId = state.pathParameters['friendId']!;
        return FriendDetailScreen(friendId: friendId);
      },
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
    GoRoute(
      path: '/add-expense',
      name: 'add-expense',
      builder: (context, state) => const AddExpenseScreen(),
    ),
    GoRoute(
      path: '/add-expense/:groupId',
      name: 'add-expense-to-group',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId'];
        return AddExpenseScreen(groupId: groupId);
      },
    ),
    GoRoute(
      path: '/expense/:expenseId',
      name: 'expense-detail',
      builder: (context, state) {
        final expenseId = state.pathParameters['expenseId']!;
        return ExpenseDetailScreen(expenseId: expenseId);
      },
    ),
    GoRoute(
      path: '/settle/:userId',
      name: 'settle',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return SettleScreen(recipientUserId: userId);
      },
    ),
    GoRoute(
      path: '/reports',
      name: 'reports',
      builder: (context, state) => const ReportsScreen(),
    ),
  ],
);
