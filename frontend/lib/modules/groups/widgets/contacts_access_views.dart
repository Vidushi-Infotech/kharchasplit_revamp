import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/contacts_access.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Current contacts access; re-read after the person changes it (picker,
/// Settings) by invalidating.
final contactsAccessProvider = FutureProvider.autoDispose<ContactsAccess>(
  (ref) => ContactsAccessService.status(),
);

/// Strip above the contact list when iOS gave the app only some contacts:
/// "You've shared 3 contacts · Add more · Allow all" (the pattern Apple
/// recommends for limited access).
class ContactsLimitedBanner extends StatelessWidget {
  const ContactsLimitedBanner({
    super.key,
    required this.sharedCount,
    required this.onAddMore,
    required this.onAllowAll,
  });

  final int sharedCount;
  final VoidCallback onAddMore;
  final VoidCallback onAllowAll;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_person_outlined,
            size: 20,
            color: AppColors.brand,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.contactsSharedCount(sharedCount),
              style: AppTextStyles.body2(isDark),
            ),
          ),
          TextButton(
            onPressed: onAddMore,
            child: const Text(AppStrings.contactsAddMore),
          ),
          TextButton(
            onPressed: onAllowAll,
            child: const Text(AppStrings.contactsAllowAll),
          ),
        ],
      ),
    );
  }
}

/// Shown instead of "No contacts on this device" when the real reason is
/// the permission: nothing shared yet (limited) or access turned off.
/// Always offers the system picker, which works without any permission,
/// and points at the number search above.
class ContactsAccessEmpty extends StatelessWidget {
  const ContactsAccessEmpty({
    super.key,
    required this.access,
    required this.onAddMore,
    required this.onOpenSettings,
    required this.onPickContact,
  });

  final ContactsAccess access;
  final VoidCallback onAddMore;
  final VoidCallback onOpenSettings;
  final VoidCallback onPickContact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final limited = access == ContactsAccess.limited;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              limited ? Icons.person_search_outlined : Icons.contacts_outlined,
              size: 48,
              color: AppColors.textSecondary(isDark),
            ),
            const SizedBox(height: 12),
            Text(
              limited
                  ? AppStrings.contactsNoneSharedTitle
                  : AppStrings.contactsAccessOffTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.headline3(isDark),
            ),
            const SizedBox(height: 6),
            Text(
              limited
                  ? AppStrings.contactsNoneSharedBody
                  : AppStrings.contactsAccessOffBody,
              textAlign: TextAlign.center,
              style: AppTextStyles.body2(
                isDark,
              ).copyWith(color: AppColors.textSecondary(isDark)),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: limited ? onAddMore : onOpenSettings,
              icon: Icon(
                limited
                    ? Icons.person_add_alt_1_rounded
                    : Icons.settings_outlined,
              ),
              label: Text(
                limited
                    ? AppStrings.contactsChooseToShare
                    : AppStrings.openSettings,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onPickContact,
              icon: const Icon(Icons.contact_phone_outlined),
              label: const Text(AppStrings.contactsPickOne),
            ),
            if (limited) ...[
              TextButton(
                onPressed: onOpenSettings,
                child: const Text(AppStrings.contactsAllowAllInSettings),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              AppStrings.contactsOrTypeNumber,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(isDark),
            ),
          ],
        ),
      ),
    );
  }
}
