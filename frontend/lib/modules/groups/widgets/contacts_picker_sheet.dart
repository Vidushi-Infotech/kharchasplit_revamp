import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/contacts/device_contacts_provider.dart';
import '../../../data/users/users_repository.dart';
import '../state/registered_users_provider.dart';

/// Shows the device-contacts picker as a modal bottom sheet and resolves to
/// the user's selection (empty if cancelled). Used by Create Group and the
/// in-group "Add member" flow.
///
/// [doneLabel] is the label shown on the confirm button.
/// [registeredCtaLabel] / [unregisteredCtaLabel] customize the per-row CTAs.
/// [existingMemberPhones] are phone numbers (any format) of people already in
/// the target group — they appear with a disabled "Added" chip and cannot be
/// re-selected. Phones are normalized internally before comparison.
Future<List<Contact>> showContactsPicker(
  BuildContext context, {
  List<Contact> initialSelected = const [],
  String doneLabel = 'Done',
  String registeredCtaLabel = 'Add',
  String unregisteredCtaLabel = 'Add & Invite',
  Iterable<String> existingMemberPhones = const [],
}) async {
  final picked = await showModalBottomSheet<List<Contact>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ContactsPickerSheet(
      initialSelected: initialSelected,
      doneLabel: doneLabel,
      registeredCtaLabel: registeredCtaLabel,
      unregisteredCtaLabel: unregisteredCtaLabel,
      existingMemberPhones: existingMemberPhones
          .map((p) => normalizePhone(p.trim()))
          .where((p) => p.isNotEmpty)
          .toSet(),
    ),
  );
  return picked ?? const [];
}

class ContactsPickerSheet extends ConsumerStatefulWidget {
  final List<Contact> initialSelected;
  final String doneLabel;
  final String registeredCtaLabel;
  final String unregisteredCtaLabel;
  final Set<String> existingMemberPhones;

  const ContactsPickerSheet({
    super.key,
    this.initialSelected = const [],
    this.doneLabel = 'Done',
    this.registeredCtaLabel = 'Add',
    this.unregisteredCtaLabel = 'Add & Invite',
    this.existingMemberPhones = const {},
  });

  @override
  ConsumerState<ContactsPickerSheet> createState() =>
      _ContactsPickerSheetState();
}

class _ContactsPickerSheetState extends ConsumerState<ContactsPickerSheet> {
  late Set<String> _selectedIds;
  late TextEditingController _searchController;
  String _query = '';
  Set<String> _registeredPhones = const {};
  bool _registrationLookupStarted = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initialSelected.map((c) => c.id).toSet();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deviceContactsProvider.notifier).silentRefresh();
    });
  }

  Future<void> _loadRegisteredPhones(List<Contact> contacts) async {
    if (_registrationLookupStarted) return;
    _registrationLookupStarted = true;
    final phones = <String>[];
    for (final c in contacts) {
      for (final p in c.phones) {
        if (p.number.trim().isNotEmpty) phones.add(p.number.trim());
      }
    }
    if (phones.isEmpty) return;
    try {
      final result =
          await ref.read(usersRepositoryProvider).checkRegistration(phones);
      if (!mounted) return;
      setState(() => _registeredPhones = result);
    } catch (_) {
      // Soft failure — leave _registeredPhones empty.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncContacts = ref.watch(deviceContactsProvider);

    asyncContacts.whenData((c) {
      if (!_registrationLookupStarted && c.isNotEmpty) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _loadRegisteredPhones(c));
      }
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return SafeArea(
          child: Column(
            children: [
              _SheetHeader(
                count: _selectedIds.length,
                doneLabel: widget.doneLabel,
                onDone: () {
                  final allContacts = asyncContacts.value ?? const <Contact>[];
                  final selected = allContacts
                      .where((c) => _selectedIds.contains(c.id))
                      .toList();
                  Navigator.of(context).pop(selected);
                },
                isDark: isDark,
              ),
              _SearchField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: asyncContacts.when(
                  loading: () =>
                      _ContactsSkeleton(controller: scrollController),
                  error: (err, _) => _ContactsError(
                    error: err,
                    onRetry: () =>
                        ref.read(deviceContactsProvider.notifier).refresh(),
                  ),
                  data: (contacts) {
                    final filtered = _filter(contacts);
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          contacts.isEmpty
                              ? 'No contacts on this device'
                              : 'No matches for "$_query"',
                          style: AppTextStyles.body2(isDark).copyWith(
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                      );
                    }
                    final items = _sectionItems(filtered);
                    return RefreshIndicator(
                      onRefresh: () =>
                          ref.read(deviceContactsProvider.notifier).refresh(),
                      child: ListView.builder(
                        controller: scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final item = items[i];
                          if (item is _SectionHeaderItem) {
                            return _SectionHeader(
                              title: item.title,
                              count: item.count,
                              isDark: isDark,
                            );
                          }
                          if (item is _ContactItem) {
                            return _buildContactTile(item.contact, isDark);
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Contact> _filter(List<Contact> contacts) {
    if (_query.isEmpty) return contacts;
    final q = _query.toLowerCase();
    return contacts
        .where((c) => c.displayName.toLowerCase().contains(q))
        .toList();
  }

  List<_PickerItem> _sectionItems(List<Contact> filtered) {
    if (_registeredPhones.isEmpty) {
      return filtered.map<_PickerItem>((c) => _ContactItem(c)).toList();
    }
    final onApp = <Contact>[];
    final others = <Contact>[];
    for (final c in filtered) {
      final isReg = c.phones.any((p) {
        final t = p.number.trim();
        return t.isNotEmpty && _registeredPhones.contains(normalizePhone(t));
      });
      (isReg ? onApp : others).add(c);
    }
    final out = <_PickerItem>[];
    if (onApp.isNotEmpty) {
      out.add(_SectionHeaderItem('On KharchaSplit', onApp.length));
      out.addAll(onApp.map(_ContactItem.new));
    }
    if (others.isNotEmpty) {
      out.add(_SectionHeaderItem('Invite to KharchaSplit', others.length));
      out.addAll(others.map(_ContactItem.new));
    }
    return out;
  }

  bool _isAlreadyMember(Contact c) {
    if (widget.existingMemberPhones.isEmpty) return false;
    return c.phones.any((p) {
      final t = p.number.trim();
      return t.isNotEmpty &&
          widget.existingMemberPhones.contains(normalizePhone(t));
    });
  }

  Widget _buildContactTile(Contact c, bool isDark) {
    final alreadyMember = _isAlreadyMember(c);
    final isSelected = _selectedIds.contains(c.id);
    final name = c.displayName.isEmpty ? 'Unknown' : c.displayName;
    final phone = c.phones.isNotEmpty ? c.phones.first.number : '';
    final subtitle = phone.isNotEmpty
        ? phone
        : (c.emails.isNotEmpty ? c.emails.first.address : '');
    final isRegistered =
        phone.isNotEmpty && _registeredPhones.contains(normalizePhone(phone));
    return Opacity(
      opacity: alreadyMember ? 0.55 : 1.0,
      child: ListTile(
        onTap: alreadyMember ? null : () => _toggle(c.id),
        title: Text(name),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        leading: CircleAvatar(
          backgroundColor: AppColors.brand.withValues(alpha: 0.2),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(color: AppColors.brand),
          ),
        ),
        trailing: alreadyMember
            ? _AlreadyAddedChip(isDark: isDark)
            : _buildActionButton(
                isRegistered: isRegistered,
                isSelected: isSelected,
                onTap: () => _toggle(c.id),
              ),
      ),
    );
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Widget _buildActionButton({
    required bool isRegistered,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    if (isSelected) {
      return TextButton.icon(
        onPressed: onTap,
        icon: Icon(Icons.check_circle, color: AppColors.brand, size: 18),
        label: Text(
          isRegistered ? 'Added' : 'Invited',
          style: TextStyle(color: AppColors.brand),
        ),
      );
    }
    if (isRegistered) {
      return FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          minimumSize: const Size(72, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Text(widget.registeredCtaLabel),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brand,
        side: BorderSide(color: AppColors.brand),
        minimumSize: const Size(96, 36),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      child: Text(widget.unregisteredCtaLabel),
    );
  }
}

class _AlreadyAddedChip extends StatelessWidget {
  const _AlreadyAddedChip({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.textSecondary(isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            'Added',
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.count,
    required this.onDone,
    required this.isDark,
    required this.doneLabel,
  });

  final int count;
  final VoidCallback onDone;
  final bool isDark;
  final String doneLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Text('Select Contacts',
                style: AppTextStyles.headline3(isDark)),
          ),
          TextButton(
            onPressed: onDone,
            child: Text('$doneLabel ($count)'),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search contacts',
          prefixIcon: const Icon(Icons.search_rounded),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _ContactsSkeleton extends StatelessWidget {
  const _ContactsSkeleton({required this.controller});
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerColor = AppColors.divider(isDark);
    return ListView.builder(
      controller: controller,
      itemCount: 12,
      itemBuilder: (_, __) => ListTile(
        leading: CircleAvatar(backgroundColor: shimmerColor),
        title: Container(
          height: 14,
          margin: const EdgeInsets.only(right: 80, top: 4, bottom: 4),
          decoration: BoxDecoration(
            color: shimmerColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        subtitle: Container(
          height: 10,
          margin: const EdgeInsets.only(right: 140, top: 4, bottom: 4),
          decoration: BoxDecoration(
            color: shimmerColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

sealed class _PickerItem {
  const _PickerItem();
}

class _ContactItem extends _PickerItem {
  const _ContactItem(this.contact);
  final Contact contact;
}

class _SectionHeaderItem extends _PickerItem {
  const _SectionHeaderItem(this.title, this.count);
  final String title;
  final int count;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.isDark,
  });

  final String title;
  final int count;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      color: AppColors.background(isDark),
      child: Text(
        '$title  ·  $count',
        style: AppTextStyles.caption(isDark).copyWith(
          color: AppColors.textSecondary(isDark),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ContactsError extends StatelessWidget {
  const _ContactsError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPermissionDenied = error is ContactsPermissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPermissionDenied
                  ? Icons.contacts_outlined
                  : Icons.error_outline_rounded,
              size: 48,
              color: AppColors.textSecondary(isDark),
            ),
            const SizedBox(height: 12),
            Text(
              isPermissionDenied
                  ? 'Contacts access needed'
                  : "Couldn't load contacts",
              style: AppTextStyles.headline3(isDark),
            ),
            const SizedBox(height: 6),
            Text(
              isPermissionDenied
                  ? 'Allow Contacts access from Settings to invite friends from your phone book.'
                  : error.toString(),
              textAlign: TextAlign.center,
              style: AppTextStyles.body2(isDark)
                  .copyWith(color: AppColors.textSecondary(isDark)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
