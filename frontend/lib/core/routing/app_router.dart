import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../modules/onboarding/screens/onboarding_screen.dart';
import '../../modules/auth/screens/login_screen.dart';
import '../../modules/auth/screens/register_screen.dart';
import '../../modules/auth/screens/profile_setup_screen.dart';
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
import '../../modules/notifications/screens/notifications_inbox_screen.dart';
import '../../modules/profile/screens/profile_screen.dart';
import '../../modules/profile/screens/edit_profile_screen.dart';
import '../../modules/profile/screens/notifications_settings_screen.dart';
import '../../modules/profile/screens/security_screen.dart';
import '../../modules/profile/screens/active_sessions_screen.dart';
import '../../modules/profile/screens/policy_screen.dart';
import '../../modules/expenses/screens/add_expense_screen.dart';
import '../../modules/expenses/screens/expense_detail_screen.dart';
import '../../modules/personal_expenses/screens/personal_expenses_screen.dart';
import '../../modules/personal_expenses/screens/add_personal_expense_screen.dart';
import '../../modules/reports/screens/reports_screen.dart';
import '../../modules/settlements/screens/settle_screen.dart';
import '../../modules/settlements/screens/settlement_history_screen.dart';
import '../../layouts/shell/mobile_shell.dart';
import '../../layouts/shell/tablet_shell.dart';
import '../../layouts/shell/web_shell.dart';
import '../responsive/breakpoints.dart';
import 'route_error_screen.dart';
import 'web_deep_link.dart';

/// Shell for the five primary tab destinations — bottom bar, rail or sidebar
/// depending on width. Unchanged from the original inline builder.
Widget _tabShell(BuildContext context, Widget child) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  if (screenWidth < Breakpoints.shellTablet) {
    return MobileShell(child: child);
  } else if (screenWidth < Breakpoints.shellWeb) {
    return TabletShell(child: child);
  } else {
    return WebShell(child: child);
  }
}

/// Shell for every other in-app route — detail pages, forms, reports.
///
/// These used to render as bare full-window scaffolds at every width, which
/// left desktop users with no navigation on 24 of 30 routes. Below
/// [Breakpoints.shellWeb] this still returns the child untouched, so the
/// approved mobile and tablet presentation of these screens is byte-identical
/// to before — notably, they do *not* gain the mobile bottom bar.
Widget _contentShell(BuildContext context, Widget child) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  if (screenWidth < Breakpoints.shellWeb) return child;
  return WebShell(child: child);
}

final appRouter = GoRouter(
  initialLocation: '/',
  errorBuilder: (context, state) =>
      RouteErrorScreen(location: state.uri.toString()),
  // Web only: a protected URL opened cold is stashed and replayed after the
  // splash screen resolves auth, instead of rendering a signed-out screen.
  // Returns null for every navigation once the app has booted, and for every
  // navigation on mobile.
  redirect: (context, state) => WebDeepLink.captureIfColdStart(state.uri.path),
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
      path: '/profile-setup',
      name: 'profile-setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      name: 'forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => _tabShell(context, child),
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
          path: '/home/personal',
          name: 'personal',
          builder: (context, state) => const PersonalExpensesScreen(),
        ),
        // Friends route kept for deep links from group/expense screens.
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
      ],
    ),
    ShellRoute(
      builder: (context, state, child) => _contentShell(context, child),
      routes: [
        GoRoute(
          path: '/home/notifications',
          name: 'notifications-inbox',
          builder: (context, state) => const NotificationsInboxScreen(),
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
          path: '/home/personal/new',
          name: 'add-personal-expense',
          builder: (context, state) => const AddPersonalExpenseScreen(),
        ),
        GoRoute(
          path: '/home/profile/edit',
          name: 'edit-profile',
          builder: (context, state) => const EditProfileScreen(),
        ),
        GoRoute(
          path: '/home/profile/notifications',
          name: 'notification-settings',
          builder: (context, state) => const NotificationsSettingsScreen(),
        ),
        GoRoute(
          path: '/home/profile/security',
          name: 'security',
          builder: (context, state) => const SecurityScreen(),
        ),
        GoRoute(
          path: '/home/profile/security/sessions',
          name: 'active-sessions',
          builder: (context, state) => const ActiveSessionsScreen(),
        ),
        GoRoute(
          path: '/home/profile/privacy',
          name: 'privacy-policy',
          builder: (context, state) => const PolicyScreen(
            kind: 'privacy',
            fallbackTitle: 'Privacy Policy',
          ),
        ),
        GoRoute(
          path: '/home/profile/terms',
          name: 'terms',
          builder: (context, state) => const PolicyScreen(
            kind: 'terms',
            fallbackTitle: 'Terms of Service',
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
          path: '/expense/:expenseId/edit',
          name: 'edit-expense',
          builder: (context, state) {
            final expenseId = state.pathParameters['expenseId']!;
            return AddExpenseScreen(expenseId: expenseId);
          },
        ),
        GoRoute(
          path: '/home/groups/:groupId/settlements-with/:userId',
          name: 'settlement-history',
          builder: (context, state) => SettlementHistoryScreen(
            groupId: state.pathParameters['groupId']!,
            otherUserId: state.pathParameters['userId']!,
          ),
        ),
        GoRoute(
          path: '/settle/:userId',
          name: 'settle',
          builder: (context, state) {
            final userId = state.pathParameters['userId']!;
            final groupId = state.uri.queryParameters['groupId'];
            final amount = double.tryParse(
              state.uri.queryParameters['amount'] ?? '',
            );
            return SettleScreen(
              recipientUserId: userId,
              initialGroupId: groupId,
              initialAmount: amount,
            );
          },
        ),
        GoRoute(
          path: '/reports',
          name: 'reports',
          builder: (context, state) => const ReportsScreen(),
        ),
      ],
    ),
  ],
);
