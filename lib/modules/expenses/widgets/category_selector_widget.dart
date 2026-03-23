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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: CategoryModel.all.map((category) {
          final isSelected = selectedCategory?.id == category.id;
          final categoryColor = _hexToColor(category.colorHex);

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => onCategorySelected(category),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? categoryColor.withOpacity(0.2)
                      : AppColors.divider(isDark),
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: categoryColor, width: 2)
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(category.icon, size: 20, color: categoryColor),
                    const SizedBox(width: 8),
                    Text(
                      category.name,
                      style: TextStyle(
                        color: AppColors.textPrimary(isDark),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
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
