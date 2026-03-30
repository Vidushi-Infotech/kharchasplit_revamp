import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class FriendSearchWidget extends StatefulWidget {
  final Function(String) onSearch;
  final VoidCallback? onClear;
  final String hintText;
  final bool isLoading;

  const FriendSearchWidget({
    super.key,
    required this.onSearch,
    this.onClear,
    this.hintText = 'Search contacts by name or phone...',
    this.isLoading = false,
  });

  @override
  State<FriendSearchWidget> createState() => _FriendSearchWidgetState();
}

class _FriendSearchWidgetState extends State<FriendSearchWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: 'Search contacts field',
      textField: true,
      child: TextField(
        controller: _controller,
        enabled: !widget.isLoading,
        onChanged: widget.onSearch,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(color: AppColors.textSecondary(isDark)),
          prefixIcon: Semantics(
            label: 'Search icon',
            child: Icon(
              Icons.search_rounded,
              color: AppColors.brand,
              size: 20,
            ),
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _controller.clear();
                    widget.onSearch('');
                    widget.onClear?.call();
                  },
                  child: Semantics(
                    label: 'Clear search',
                    button: true,
                    onTap: () {
                      _controller.clear();
                      widget.onSearch('');
                      widget.onClear?.call();
                    },
                    child: Icon(
                      Icons.close_rounded,
                      color: AppColors.brand,
                      size: 20,
                    ),
                  ),
                )
              : null,
          filled: true,
          fillColor: AppColors.inputFill(isDark),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.inputBorder(isDark)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.inputBorder(isDark)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: AppColors.brand,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
