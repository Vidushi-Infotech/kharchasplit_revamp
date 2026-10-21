import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/search/search_repository.dart';

/// Back arrow + the search field. The controller and focus node belong to
/// the screen (which disposes them).
class SearchBarHeader extends StatelessWidget {
  const SearchBarHeader({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.horizontalPadding,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onBack,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final double horizontalPadding;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding - 8,
        8,
        horizontalPadding,
        8,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.textPrimary(isDark),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              maxLength: searchMaxQueryLength,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: AppTextStyles.body1(isDark),
              decoration: InputDecoration(
                counterText: '',
                isDense: true,
                filled: true,
                fillColor: AppColors.inputFill(isDark),
                hintText: AppStrings.searchHint,
                hintStyle: AppTextStyles.body1(
                  isDark,
                ).copyWith(color: AppColors.textSecondary(isDark)),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary(isDark),
                ),
                // Rebuilds with the text so the × only shows when useful.
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: AppColors.textSecondary(isDark),
                          tooltip: AppStrings.searchClear,
                          onPressed: onClear,
                        ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.inputBorder(isDark)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.inputBorder(isDark)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.brand,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
