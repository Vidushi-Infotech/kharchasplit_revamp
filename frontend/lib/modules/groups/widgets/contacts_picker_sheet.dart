import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/contacts/device_contacts_provider.dart';
import '../../../data/users/users_repository.dart';
import '../state/registered_users_provider.dart';

/// Link surfaced by the Copy / Share buttons inside the invite bottom
/// sheet. Intentionally NOT used inside the SMTP email template — the
/// email already has its own Play Store / App Store badges.
const String _kInviteShareUrl = 'https://kharchasplit.com/';

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

  /// Per-contact email entered via the "Add & Invite" popup. Keyed by
  /// `contact.id`. Injected onto each contact's `emails` list right before
  /// the sheet returns its selection, so callers can iterate
  /// `c.emails.first.address` to drive the SMTP fallback invite.
  final Map<String, String> _enteredEmails = {};

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
                  // Attach the user-entered email (if any) so the caller can
                  // run an SMTP invite alongside the WATI phone invite. We
                  // prepend so the entered address wins over any device-book
                  // email we might want to keep further down the list.
                  for (final c in selected) {
                    final extra = _enteredEmails[c.id];
                    if (extra != null && extra.isNotEmpty) {
                      c.emails = [Email(extra), ...c.emails];
                    }
                  }
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
    // The "Add & Invite" path (unregistered + not already selected) goes
    // through the email popup; everything else is a plain toggle.
    void onCtaTap() {
      if (isSelected || isRegistered) {
        _toggle(c.id);
      } else {
        _handleInviteTap(c);
      }
    }

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
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        // Drop any email entered earlier — deselect should be a clean reset.
        _enteredEmails.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  /// Tapped on the "Add & Invite" pill of an unregistered contact. Pops a
  /// small dialog asking for the recipient's email so we can fall back to
  /// SMTP (since WhatsApp/WATI isn't always viable). On submit the email
  /// is stashed in [_enteredEmails] and the contact toggled selected. On
  /// cancel nothing happens — the user can tap "Add & Invite" again.
  Future<void> _handleInviteTap(Contact c) async {
    final email = await _promptInviteEmail(c);
    if (email == null) return; // cancelled
    setState(() {
      _enteredEmails[c.id] = email;
      _selectedIds.add(c.id);
    });
  }

  Future<String?> _promptInviteEmail(Contact c) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true, // lets the sheet rise above the keyboard
      backgroundColor:
          AppColors.surface(Theme.of(context).brightness == Brightness.dark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _InviteEmailDialog(
        title: c.displayName.trim().isEmpty
            ? 'Invite by email'
            : 'Invite ${c.displayName.trim()}',
        initialEmail: c.emails.isNotEmpty ? c.emails.first.address : '',
      ),
    );
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

/// Bottom-sheet body for the "Add & Invite" flow. Wraps:
///   - email entry (queued for SMTP send when the picker is Done'd)
///   - Copy link / Share link buttons that surface the static
///     [_kInviteShareUrl] (intentionally separate from the SMTP email,
///     which has its own Play Store / App Store CTA buttons).
///
/// Lives as a real StatefulWidget so the TextEditingController is disposed
/// inside the framework's normal mount/unmount cycle — disposing inline
/// after `await showModalBottomSheet` previously triggered a
/// `_dependents.isEmpty` assertion because the TextFormField hadn't
/// finished unmounting yet.
class _InviteEmailDialog extends StatefulWidget {
  const _InviteEmailDialog({
    required this.title,
    required this.initialEmail,
  });

  final String title;
  final String initialEmail;

  @override
  State<_InviteEmailDialog> createState() => _InviteEmailDialogState();
}

class _InviteEmailDialogState extends State<_InviteEmailDialog> {
  late final TextEditingController _ctrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_ctrl.text.trim());
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(const ClipboardData(text: _kInviteShareUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard')),
    );
  }

  Future<void> _shareLink() async {
    // Share sheet uses the device's native sharing intent (WhatsApp,
    // SMS, email, etc.). Lets the inviter use their own messaging app
    // when they don't want to wait for the SMTP email to arrive.
    await SharePlus.instance.share(
      ShareParams(
        text: 'Join me on KharchaSplit: $_kInviteShareUrl',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Padding for the keyboard so the email field stays above it.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            widget.title,
            style: AppTextStyles.body1(isDark)
                .copyWith(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 16),

          // Email entry — queued for SMTP send on picker Done.
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.send,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'name@example.com',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Email is required';
                if (!s.contains('@') || !s.contains('.')) {
                  return 'Enter a valid email';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Add'),
                ),
              ),
            ],
          ),

          // Visual separator before the link-share section.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(child: Divider(color: AppColors.divider(isDark))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'or share a link',
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ),
                Expanded(child: Divider(color: AppColors.divider(isDark))),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyLink,
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppColors.brand),
                    foregroundColor: AppColors.brand,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareLink,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppColors.brand),
                    foregroundColor: AppColors.brand,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
