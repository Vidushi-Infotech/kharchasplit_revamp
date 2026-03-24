import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/models.dart';

class CategorySelectorWidget extends StatelessWidget {
  final CategoryModel? selectedCategory;
  final Function(CategoryModel) onCategorySelected;

  const CategorySelectorWidget({
    Key? key,
    required this.selectedCategory,
    required this.onCategorySelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    final categoryButtons = CategoryModel.all.map((category) {
      final isSelected = selectedCategory?.id == category.id;
      final categoryColor = _hexToColor(category.colorHex);

      return Padding(
        padding: EdgeInsets.only(
          right: isCompact ? 8 : 12,
        ),
        child: Semantics(
          button: true,
          label:
              '${category.name} category${isSelected ? ' - selected' : ''}',
          onTap: () => onCategorySelected(category),
          child: GestureDetector(
            onTap: () => onCategorySelected(category),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 10 : 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? categoryColor.withValues(alpha: 0.2)
                    : AppColors.surface(isDark),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? categoryColor : AppColors.divider(isDark),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    category.icon,
                    size: 18,
                    color: categoryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category.name,
                    style: TextStyle(
                      fontSize: isCompact ? 12 : 14,
                      color: AppColors.textPrimary(isDark),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: categoryButtons.length,
        itemBuilder: (context, index) => categoryButtons[index],
      ),
    );
  }

  /// Parse hex color string to Color object
  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) {
      buffer.write('ff');
    }
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
