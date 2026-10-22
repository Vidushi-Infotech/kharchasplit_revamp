import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Page chrome for the Add/Edit expense form: back-guard ([PopScope] routes
/// system back through [onClose]), the [topBar] (✕ title ✓ Save), the
/// scrollable centred [form] and the [bottomBar] (date / group / receipt /
/// notes) that rides up with the keyboard. Width metrics come from the
/// screen.
class AddExpenseFormScaffold extends StatelessWidget {
  const AddExpenseFormScaffold({
    super.key,
    required this.isDark,
    required this.topBar,
    required this.onClose,
    required this.horizontalPad,
    required this.maxFormWidth,
    required this.form,
    required this.bottomBar,
  });

  final bool isDark;
  final PreferredSizeWidget topBar;
  final VoidCallback onClose;
  final double horizontalPad;
  final double maxFormWidth;
  final Widget form;
  final Widget bottomBar;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        onClose();
      },
      child: Scaffold(
        backgroundColor: AppColors.background(isDark),
        appBar: topBar,
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    12,
                    horizontalPad,
                    24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxFormWidth),
                      child: form,
                    ),
                  ),
                ),
              ),
              bottomBar,
            ],
          ),
        ),
      ),
    );
  }
}
