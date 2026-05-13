// Template: frontend/lib/modules/<feature>/screens/<feature>_screen.dart
//
// 3-breakpoint ConsumerStatefulWidget with loading/error/empty handling.
// Replace <Feature> / <feature> placeholders. Keep this file < 300 lines.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../components/states/empty_state_widget.dart';
import '../../../components/states/error_state_widget.dart';
import '../../../components/loaders/shimmer_list.dart';
import '../state/<feature>_provider.dart';

class <Feature>Screen extends ConsumerStatefulWidget {
  const <Feature>Screen({super.key});

  @override
  ConsumerState<<Feature>Screen> createState() => _<Feature>ScreenState();
}

class _<Feature>ScreenState extends ConsumerState<<Feature>Screen> {
  // Declare and dispose any controllers in initState / dispose.

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 600) {
      return _buildCompactLayout(isDark);
    } else if (screenWidth < 1100) {
      return _buildStandardLayout(isDark);
    } else {
      return _buildLargeLayout(isDark);
    }
  }

  // ---------- Layouts ----------

  Widget _buildCompactLayout(bool isDark) {
    return Scaffold(
      appBar: AppBar(title: const Text('<Feature>')),
      body: _buildBody(isDark, padding: const EdgeInsets.all(16)),
    );
  }

  Widget _buildStandardLayout(bool isDark) {
    return Scaffold(
      appBar: AppBar(title: const Text('<Feature>')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _buildBody(isDark, padding: const EdgeInsets.all(24)),
        ),
      ),
    );
  }

  Widget _buildLargeLayout(bool isDark) {
    return Scaffold(
      appBar: AppBar(title: const Text('<Feature>')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: _buildBody(isDark, padding: const EdgeInsets.all(32)),
        ),
      ),
    );
  }

  // ---------- Body ----------

  Widget _buildBody(bool isDark, {required EdgeInsets padding}) {
    final asyncValue = ref.watch(<feature>Provider);

    return asyncValue.when(
      loading: () => const ShimmerList(itemCount: 6),
      error: (err, _) => ErrorStateWidget(
        message: err.toString(),
        onRetry: () => ref.read(<feature>Provider.notifier).refresh(),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.inbox_outlined,
            title: 'Nothing here yet',
            message: 'Once you add a <feature>, it will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(<feature>Provider.notifier).refresh(),
          child: ListView.builder(
            padding: padding,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.toString(), style: AppTextStyles.bodyMedium(isDark)),
              );
            },
          ),
        );
      },
    );
  }
}
