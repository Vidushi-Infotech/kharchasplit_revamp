import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/expense_comments_provider.dart';

/// "Add a comment" box pinned to the bottom of the expense detail screen.
/// Sits in the Scaffold body, so it rides up with the keyboard; errors
/// (too fast, too long, offline) show in a SnackBar and keep the text.
class ExpenseCommentInput extends ConsumerStatefulWidget {
  const ExpenseCommentInput({
    super.key,
    required this.expenseId,
    required this.isDark,
    this.maxWidth = 720,
  });

  final String expenseId;
  final bool isDark;

  /// Matches the content column above it on wide layouts.
  final double maxWidth;

  @override
  ConsumerState<ExpenseCommentInput> createState() =>
      _ExpenseCommentInputState();
}

class _ExpenseCommentInputState extends ConsumerState<ExpenseCommentInput> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  // Local UI flag only: disables Send while the POST is in flight.
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(expenseCommentsControllerProvider)
        .add(widget.expenseId, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    } else {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final canSend = _controller.text.trim().isNotEmpty && !_sending;

    return Material(
      color: AppColors.background(isDark),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider(isDark))),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.maxWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: ExpenseCommentsController.maxLength,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.newline,
                        style: AppTextStyles.body2(isDark),
                        decoration: InputDecoration(
                          hintText: AppStrings.addComment,
                          counterText: '',
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.cardBg(isDark),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: AppColors.divider(isDark),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: AppColors.divider(isDark),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: AppStrings.sendComment,
                      onPressed: canSend ? _send : null,
                      color: AppColors.tealDark,
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
