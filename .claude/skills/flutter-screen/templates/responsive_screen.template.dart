// Template: frontend/lib/modules/<module>/screens/<screen_name>_screen.dart
//
// 3-breakpoint responsive screen with loading/error/empty states.
// Pattern verified against:
//   - frontend/lib/modules/expenses/screens/add_expense_screen.dart
//   - frontend/lib/modules/activity/screens/activity_screen.dart
//   - frontend/lib/core/routing/app_router.dart (ShellRoute breakpoints)
//
// Replace placeholders: <ScreenName>, <screen_name>, <module>, <provider>.
// Keep this file < 300 lines — extract widgets to ../widgets/ when it grows.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../components/loaders/shimmer_list.dart';
import '../../../components/states/empty_state_widget.dart';
import '../../../components/states/error_state_widget.dart';
// import '../state/<provider>_provider.dart';

class <ScreenName>Screen extends ConsumerStatefulWidget {
  const <ScreenName>Screen({super.key /* , required this.id */});

  // final String id; // uncomment if route passes a param

  @override
  ConsumerState<<ScreenName>Screen> createState() => _<ScreenName>ScreenState();
}

class _<ScreenName>ScreenState extends ConsumerState<<ScreenName>Screen> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 600) return _buildCompactLayout(isDark);
    if (screenWidth < 1100) return _buildStandardLayout(isDark);
    return _buildLargeLayout(isDark);
  }

  // ---------- Layouts ----------

  Widget _buildCompactLayout(bool isDark) {
    return Scaffold(
      appBar: AppBar(title: const Text('<ScreenName>')),
      body: _buildBody(isDark, const EdgeInsets.all(16)),
    );
  }

  Widget _buildStandardLayout(bool isDark) {
    return Scaffold(
      appBar: AppBar(title: const Text('<ScreenName>')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _buildBody(isDark, const EdgeInsets.all(24)),
        ),
      ),
    );
  }

  Widget _buildLargeLayout(bool isDark) {
    return Scaffold(
      appBar: AppBar(title: const Text('<ScreenName>')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: _buildBody(isDark, const EdgeInsets.all(32)),
        ),
      ),
    );
  }

  // ---------- Shared body ----------

  Widget _buildBody(bool isDark, EdgeInsets padding) {
    // Replace with the actual provider you depend on.
    // final asyncValue = ref.watch(<provider>);
    final asyncValue = const AsyncValue<List<String>>.data([]);

    return asyncValue.when(
      loading: () => const ShimmerList(itemCount: 6),
      error: (err, _) => ErrorStateWidget(
        message: err.toString(),
        onRetry: () {
          // ref.read(<provider>.notifier).refresh();
        },
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.inbox_outlined,
            title: 'Nothing yet',
            message: 'When data appears, it will be shown here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            // await ref.read(<provider>.notifier).refresh();
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: padding,
            itemCount: items.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(items[index], style: AppTextStyles.bodyMedium(isDark)),
            ),
          ),
        );
      },
    );
  }
}
