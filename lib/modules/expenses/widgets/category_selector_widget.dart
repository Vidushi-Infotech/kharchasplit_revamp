import 'package:flutter/material.dart';
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: CategoryModel.all.map((category) {
          final isSelected = selectedCategory?.id == category.id;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => onCategorySelected(category),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? category.icon.hashCode.abs() % 2 == 0 ?  Colors.blue : Colors.red
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: Colors.blue, width: 2)
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(category.icon, size: 20),
                    const SizedBox(width: 8),
                    Text(category.name),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
