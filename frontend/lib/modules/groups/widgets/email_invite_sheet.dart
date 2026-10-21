import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class EmailInviteSheet extends StatefulWidget {
  const EmailInviteSheet({
    super.key,
    required this.memberName,
    required this.isDark,
  });

  final String memberName;
  final bool isDark;

  @override
  State<EmailInviteSheet> createState() => _EmailInviteSheetState();
}

class _EmailInviteSheetState extends State<EmailInviteSheet> {
  late final TextEditingController _ctrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider(widget.isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Invite ${widget.memberName}',
            style: AppTextStyles.body1(
              widget.isDark,
            ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 16),
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Send Invite'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
