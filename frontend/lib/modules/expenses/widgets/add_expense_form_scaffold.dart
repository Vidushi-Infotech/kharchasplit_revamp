import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'add_expense_top_bar.dart';

/// Page chrome for the Add/Edit expense form: back-guard ([PopScope] routes
/// system back through [onClose]), top bar, scrollable centred [form] and the
/// sticky [saveBar] underneath. Width metrics come from the screen.
class AddExpenseFormScaffold extends StatelessWidget {
  const AddExpenseFormScaffold({
    super.key,
    required this.isDark,
    required this.title,
    required this.onClose,
    required this.horizontalPad,
    required this.maxFormWidth,
    required this.form,
    required this.saveBar,
  });

  final bool isDark;
  final String title;
  final VoidCallback onClose;
  final double horizontalPad;
  final double maxFormWidth;
  final Widget form;
  final Widget saveBar;

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
        appBar: AddExpenseTopBar(
          title: title,
          onClose: onClose,
          isDark: isDark,
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    16,
                    horizontalPad,
                    20,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxFormWidth),
                      child: form,
                    ),
                  ),
                ),
              ),
              saveBar,
            ],
          ),
        ),
      ),
    );
  }
}
