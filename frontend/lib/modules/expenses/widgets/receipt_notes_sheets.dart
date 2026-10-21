import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/base64_async.dart';
import '../state/add_expense_provider.dart';
import 'add_expense_sheet_header.dart';
import 'invoice_upload_widget.dart';

/// Receipt upload bottom sheet. [context] and [ref] are the Add-expense
/// screen's own.
void showReceiptSheet(
  BuildContext context,
  WidgetRef ref, {
  required bool isDark,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background(isDark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AddExpenseSheetHandle(isDark: isDark),
            AddExpenseSheetTitle(text: 'Receipt', isDark: isDark),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: InvoiceUploadWidget(
                onImageSelected: (imagePath, file) async {
                  try {
                    final bytes = await File(imagePath).readAsBytes();
                    // Off the main isolate — a full-size receipt is a
                    // multi-MB encode that would freeze the sheet.
                    final encoded = await base64EncodeAsync(bytes);
                    ref.read(addExpenseProvider.notifier).state = ref
                        .read(addExpenseProvider)
                        .copyWith(
                          invoiceImagePath: imagePath,
                          receiptBase64: encoded,
                        );
                  } catch (_) {
                    ref.read(addExpenseProvider.notifier).state = ref
                        .read(addExpenseProvider)
                        .copyWith(invoiceImagePath: imagePath);
                  }
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Notes bottom sheet. [notesController] is owned (and disposed) by the
/// Add-expense screen; [context] and [ref] are the screen's own.
void showNotesSheet(
  BuildContext context,
  WidgetRef ref, {
  required bool isDark,
  required TextEditingController notesController,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background(isDark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AddExpenseSheetHandle(isDark: isDark),
              AddExpenseSheetTitle(
                text: 'Notes',
                isDark: isDark,
                trailing: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Done',
                    style: AppTextStyles.body1(isDark).copyWith(
                      color: AppColors.tealDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: TextField(
                  controller: notesController,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Add any details…',
                    filled: true,
                    fillColor: AppColors.cardBg(isDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.divider(isDark)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.divider(isDark)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.tealDark.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    ref.read(addExpenseProvider.notifier).state = ref
                        .read(addExpenseProvider)
                        .copyWith(notes: value);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
