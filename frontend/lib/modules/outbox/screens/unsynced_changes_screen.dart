import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/buttons/glass_icon_button.dart';
import '../../../components/states/empty_state_widget.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../groups/state/groups_provider.dart';
import '../state/outbox_provider.dart';
import '../widgets/unsynced_item_tile.dart';

/// Changes made offline that aren't on the server yet: waiting for a
/// connection, or refused (with the reason) — retry, discard or open.
class UnsyncedChangesScreen extends ConsumerWidget {
  const UnsyncedChangesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = ref.watch(outboxProvider);
    final groups = ref.watch(groupsProvider).value ?? const [];
    final nameOf = {for (final g in groups) g.id: g.name};
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 600 ? 16.0 : (width < 1100 ? 24.0 : 32.0);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        // Pushed into the content shell's own navigator, where the implied
        // back button never shows — ask go_router instead.
        leading: context.canPop()
            ? GlassBackButton(onPressed: () => context.pop())
            : null,
        title: const Text(AppStrings.unsyncedChanges),
        backgroundColor: AppColors.surface(isDark),
        elevation: 0,
        actions: [
          if (items.any((i) => !i.isFailed))
            GlassTextButton(
              label: AppStrings.syncAllNow,
              onPressed: () => ref.read(outboxProvider.notifier).drain(),
            ),
          const GlassGap(width: 8),
        ],
      ),
      body: items.isEmpty
          ? const EmptyStateWidget(
              icon: '✅',
              title: AppStrings.noUnsyncedChanges,
              subtitle: '',
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView.separated(
                  padding: EdgeInsets.all(pad),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => UnsyncedItemTile(
                    item: items[i],
                    groupName: nameOf[items[i].groupId],
                    isDark: isDark,
                  ),
                ),
              ),
            ),
    );
  }
}
