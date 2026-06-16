import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/contacts/device_contacts_provider.dart';
import '../../../data/users/users_repository.dart';
import '../state/registered_users_provider.dart';

/// Link surfaced by the Copy / Share buttons inside the invite bottom
/// sheet. Intentionally NOT used inside the SMTP email template — the
/// email already has its own Play Store / App Store badges.
/// Shows the device-contacts picker as a modal bottom sheet and resolves to
/// the user's selection (empty if cancelled). Used by Create Group and the
/// in-group "Add member" flow.
///
/// [doneLabel] is the label shown on the confirm button.
/// [registeredCtaLabel] / [unregisteredCtaLabel] customize the per-row CTAs.
/// [existingMemberPhones] are phone numbers (any format) of people already in
/// the target group — they appear with a disabled "Added" chip and cannot be
/// re-selected. Phones are normalized internally before comparison.
/// [selfPhones] are the signed-in user's own phone numbers (any format). Their
/// own contact entry will still appear in the list but shows a "You" chip
/// instead of an Add button — they can't add themselves to their own group.
Future<List<Contact>> showContactsPicker(
  BuildContext context, {
  List<Contact> initialSelected = const [],
  String doneLabel = 'Done',
  String registeredCtaLabel = 'Add',
  String unregisteredCtaLabel = 'Add & Invite',
  Iterable<String> existingMemberPhones = const [],
  Iterable<String> selfPhones = const [],
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
      selfPhones: selfPhones
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
  final Set<String> selfPhones;

  const ContactsPickerSheet({
    super.key,
    this.initialSelected = const [],
    this.doneLabel = 'Done',
    this.registeredCtaLabel = 'Add',
    this.unregisteredCtaLabel = 'Add & Invite',
    this.existingMemberPhones = const {},
    this.selfPhones = const {},
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

  // Phone-search state — derived from the unified search bar above. When
  // the user types exactly 10 digits, [_phoneInput] mirrors [_query] and
  // triggers a debounced backend lookup.
  Timer? _phoneDebounce;
  String _phoneInput = '';
  PhoneLookupResult? _phoneResult;
  String? _phoneError;
  bool _phoneLooking = false;
  /// In-session cache so re-typing the same 10-digit number doesn't hit
  /// the rate-limited endpoint a second time.
  final Map<String, PhoneLookupResult?> _phoneCache = {};
  /// Synthetic Contacts representing phone-search adds (registered users
  /// the device contacts list doesn't know about). Added to the returned
  /// selection alongside device-contact picks.
  final List<Contact> _extraContacts = [];

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
    _phoneDebounce?.cancel();
    super.dispose();
  }

  // -- Unified search handler --

  /// Single entry point for the unified search bar. Updates [_query] for
  /// device-contacts filtering AND, when the query is exactly a 10-digit
  /// number, fires a debounced backend lookup so the user can add
  /// registered users whose number isn't in their phone book.
  void _onQueryChanged(String raw) {
    final isAllDigits = raw.isNotEmpty && RegExp(r'^\d+$').hasMatch(raw);
    final digits = isAllDigits ? raw : '';
    setState(() {
      _query = raw;
      _phoneInput = digits.length == 10 ? digits : '';
      _phoneError = null;
      if (digits.length != 10) {
        _phoneResult = null;
        _phoneLooking = false;
      }
    });
    _phoneDebounce?.cancel();
    if (digits.length != 10) return;
    if (_phoneCache.containsKey(digits)) {
      setState(() {
        _phoneResult = _phoneCache[digits];
        _phoneError = null;
        _phoneLooking = false;
      });
      return;
    }
    _phoneDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _runPhoneLookup(digits);
    });
  }

  Future<void> _runPhoneLookup(String digits) async {
    setState(() {
      _phoneLooking = true;
      _phoneError = null;
      _phoneResult = null;
    });
    try {
      final result =
          await ref.read(usersRepositoryProvider).lookupByPhone(digits);
      if (!mounted || _phoneInput != digits) return;
      _phoneCache[digits] = result;
      setState(() {
        _phoneResult = result;
        _phoneLooking = false;
      });
    } on UsersApiException catch (e) {
      if (!mounted || _phoneInput != digits) return;
      setState(() {
        _phoneLooking = false;
        _phoneResult = null;
        _phoneError = e.statusCode == 429
            ? 'Too many searches — try again in a few minutes.'
            : 'Lookup failed. Check your connection and try again.';
      });
    } catch (_) {
      if (!mounted || _phoneInput != digits) return;
      setState(() {
        _phoneLooking = false;
        _phoneResult = null;
        _phoneError =
            'Lookup failed. Check your connection and try again.';
      });
    }
  }

  /// True when the searched phone number is the same as one of the group's
  /// existing members. Used to render an "Already in group" chip on the
  /// result row instead of an Add button.
  bool _phoneAlreadyInGroup(String digits) {
    if (widget.existingMemberPhones.isEmpty) return false;
    return widget.existingMemberPhones.contains(normalizePhone(digits));
  }

  /// Add a phone-search hit (registered user) to the picker's selection.
  /// Synthesizes a Contact whose id is unique (`phone:<digits>`) so it can
  /// coexist with device-contact ids in [_selectedIds].
  void _addFoundUser(PhoneLookupResult user, String digits) {
    final id = 'phone:$digits';
    if (_selectedIds.contains(id)) return;
    HapticService.instance.success();
    final synthetic = Contact(
      id: id,
      displayName: user.name,
      phones: [Phone(digits)],
    );
    setState(() {
      _extraContacts.add(synthetic);
      _selectedIds.add(id);
      // Clear the unified search box so the user can search the next
      // number (or a name) immediately.
      _searchController.clear();
      _query = '';
      _phoneInput = '';
      _phoneResult = null;
      _phoneError = null;
    });
  }

  // -- Phone-result card (rendered under the unified search bar) --

  Widget _buildPhoneResultCard(bool isDark) {
    if (_phoneError != null) {
      return _phoneResultCardShell(
        isDark: isDark,
        leading: Icon(
          Icons.error_outline_rounded,
          size: 18,
          color: AppColors.textSecondary(isDark),
        ),
        title: _phoneError!,
        trailing: const SizedBox.shrink(),
      );
    }
    if (_phoneLooking) {
      return _phoneResultCardShell(
        isDark: isDark,
        leading: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: 'Searching…',
        trailing: const SizedBox.shrink(),
      );
    }
    final digits = _phoneInput;
    final alreadyAdded = _selectedIds.contains('phone:$digits');
    final r = _phoneResult;
    if (r == null) {
      // 10 digits typed but no registered user — offer the invite path.
      return _phoneResultCardShell(
        isDark: isDark,
        leading: Icon(
          Icons.person_search_rounded,
          size: 18,
          color: AppColors.textSecondary(isDark),
        ),
        title: 'No KharchaSplit user found',
        subtitle: alreadyAdded
            ? 'Already added to invite list'
            : 'They will get a WhatsApp invite',
        trailing: alreadyAdded
            ? const _AddedTickChip()
            : OutlinedButton.icon(
                onPressed: () => _addInviteForPhone(digits),
                icon: const Icon(Icons.send_rounded, size: 14),
                label: const Text('Invite'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  side: BorderSide(color: AppColors.brand),
                  minimumSize: const Size(72, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
      );
    }
    final initial = r.name.isNotEmpty ? r.name[0].toUpperCase() : '?';
    Widget trailing;
    if (r.isSelf) {
      trailing = const _SelfChip();
    } else if (_phoneAlreadyInGroup(digits)) {
      trailing = _AlreadyAddedChip(isDark: isDark);
    } else if (alreadyAdded) {
      trailing = const _AddedTickChip();
    } else {
      trailing = FilledButton.icon(
        onPressed: () => _addFoundUser(r, digits),
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Add'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          minimumSize: const Size(72, 32),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      );
    }
    return _phoneResultCardShell(
      isDark: isDark,
      leading: CircleAvatar(
        backgroundColor: AppColors.brand.withValues(alpha: 0.2),
        radius: 16,
        child: Text(
          initial,
          style: TextStyle(
            color: AppColors.brand,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: r.name,
      subtitle: r.phoneSuffix.isEmpty
          ? 'On KharchaSplit'
          : 'On KharchaSplit · ••••${r.phoneSuffix}',
      trailing: trailing,
    );
  }

  Widget _phoneResultCardShell({
    required bool isDark,
    required Widget leading,
    required String title,
    String? subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Row(
        children: [
          SizedBox(width: 32, height: 32, child: Center(child: leading)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body2(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }

  /// Add an unregistered number to the picker as a synthetic Contact so the
  /// rest of the flow (Done → invitePhone in the parent) sends it down the
  /// WhatsApp / SMS invite path.
  void _addInviteForPhone(String digits) {
    final id = 'phone:$digits';
    if (_selectedIds.contains(id)) return;
    HapticService.instance.tap();
    final synthetic = Contact(
      id: id,
      displayName: '+91 $digits',
      phones: [Phone(digits)],
    );
    setState(() {
      _extraContacts.add(synthetic);
      _selectedIds.add(id);
      _searchController.clear();
      _query = '';
      _phoneInput = '';
      _phoneResult = null;
      _phoneError = null;
    });
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
                  HapticService.instance.success();
                  final allContacts = asyncContacts.value ?? const <Contact>[];
                  // Merge device-contact picks + phone-search picks. The
                  // synthetic Contacts in [_extraContacts] use ids prefixed
                  // with `phone:` so they never collide with device ids.
                  final selected = <Contact>[
                    ...allContacts.where((c) => _selectedIds.contains(c.id)),
                    ..._extraContacts
                        .where((c) => _selectedIds.contains(c.id)),
                  ];
                  Navigator.of(context).pop(selected);
                },
                isDark: isDark,
              ),
              _SearchField(
                controller: _searchController,
                onChanged: _onQueryChanged,
              ),
              if (_phoneInput.length == 10 &&
                  (_phoneLooking ||
                      _phoneResult != null ||
                      _phoneError != null)) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildPhoneResultCard(isDark),
                ),
              ],
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
                      onRefresh: () {
                        HapticService.instance.thresholdCrossed();
                        return ref
                            .read(deviceContactsProvider.notifier)
                            .refresh();
                      },
                      child: ListView.builder(
                        controller: scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: items.length,
                        // RepaintBoundary per row — toggling selection on
                        // one contact only repaints that tile, not the
                        // whole on-screen list.
                        itemBuilder: (_, i) {
                          final item = items[i];
                          if (item is _SectionHeaderItem) {
                            return RepaintBoundary(
                              child: _SectionHeader(
                                title: item.title,
                                count: item.count,
                                isDark: isDark,
                              ),
                            );
                          }
                          if (item is _ContactItem) {
                            return RepaintBoundary(
                              child: _buildContactTile(item.contact, isDark),
                            );
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
    // Digit-only query → phone partial-match. We strip non-digits from
    // each contact's stored numbers so '+91 98765 43210' still matches
    // '98765'. Below 10 digits the user just narrows the device list;
    // at 10 digits the backend lookup card (rendered separately) also
    // surfaces registered users who aren't in the device book at all.
    if (RegExp(r'^\d+$').hasMatch(_query)) {
      return contacts
          .where((c) => c.phones.any((p) {
                final d = p.number.replaceAll(RegExp(r'\D'), '');
                return d.isNotEmpty && d.contains(_query);
              }))
          .toList();
    }
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

  /// True when this device contact resolves to the signed-in user themselves.
  /// `normalizePhone` reduces both sides to the last 10 digits, so the check
  /// works regardless of whether the contact is stored as `9999912345`,
  /// `+919999912345`, `+91 99999 12345`, etc.
  bool _isSelf(Contact c) {
    if (widget.selfPhones.isEmpty) return false;
    return c.phones.any((p) {
      final t = p.number.trim();
      return t.isNotEmpty && widget.selfPhones.contains(normalizePhone(t));
    });
  }

  Widget _buildContactTile(Contact c, bool isDark) {
    final isSelf = _isSelf(c);
    final alreadyMember = _isAlreadyMember(c);
    final isSelected = _selectedIds.contains(c.id);
    final name = c.displayName.isEmpty ? 'Unknown' : c.displayName;
    final phone = c.phones.isNotEmpty ? c.phones.first.number : '';
    final subtitle = phone.isNotEmpty
        ? phone
        : (c.emails.isNotEmpty ? c.emails.first.address : '');
    final isRegistered =
        phone.isNotEmpty && _registeredPhones.contains(normalizePhone(phone));
    void onCtaTap() => _toggle(c.id);

    // Self wins over alreadyMember — you can't add yourself, even if your
    // own row also matches the "already in group" set.
    final Widget trailing;
    if (isSelf) {
      trailing = const _SelfChip();
    } else if (alreadyMember) {
      trailing = _AlreadyAddedChip(isDark: isDark);
    } else {
      trailing = _buildActionButton(
        isRegistered: isRegistered,
        isSelected: isSelected,
        onTap: onCtaTap,
      );
    }

    return Opacity(
      opacity: (alreadyMember && !isSelf) ? 0.55 : 1.0,
      child: ListTile(
        onTap: (isSelf || alreadyMember) ? null : onCtaTap,
        title: Text(name),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        leading: CircleAvatar(
          backgroundColor: AppColors.brand.withValues(alpha: 0.2),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(color: AppColors.brand),
          ),
        ),
        trailing: trailing,
      ),
    );
  }

  void _toggle(String id) {
    HapticService.instance.tap();
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
          'Added',
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

/// Trailing badge shown on the signed-in user's own row. Visually distinct
/// from "Added" so they can tell at a glance which contact is theirs.
class _SelfChip extends StatelessWidget {
  const _SelfChip();

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_rounded, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            'You',
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
        keyboardType: TextInputType.text,
        decoration: InputDecoration(
          hintText: 'Search by name or 10-digit number',
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


/// Small "Added" pill shown when the phone-search result has already been
/// pushed into the picker's selection list during this session.
class _AddedTickChip extends StatelessWidget {
  const _AddedTickChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded,
              size: 14, color: AppColors.brand),
          const SizedBox(width: 4),
          Text(
            'Added',
            style: TextStyle(
              color: AppColors.brand,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
