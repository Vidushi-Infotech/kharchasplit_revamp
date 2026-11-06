import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Centered note plus outlined buttons at the end of a list, e.g.
/// "Hiding groups you settled up with…" / [Show 3 settled-up groups] /
/// [+ Start a new group].
class ListFooterActions extends StatelessWidget {
  const ListFooterActions({super.key, this.note, this.actions = const []});

  final String? note;
  final List<ListFooterAction> actions;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        children: [
          if (note != null) ...[
            Text(
              note!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(isDark),
                  ),
            ),
            const SizedBox(height: 12),
          ],
          for (final a in actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton.icon(
                onPressed: a.onTap,
                icon: a.icon == null ? const SizedBox.shrink() : Icon(a.icon, size: 18),
                label: Text(a.label),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  side: const BorderSide(color: AppColors.brand),
                  shape: const StadiumBorder(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ListFooterAction {
  const ListFooterAction({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
}
