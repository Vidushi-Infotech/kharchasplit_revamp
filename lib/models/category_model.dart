import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Category model for expenses
class CategoryModel extends Equatable {
  final String id;
  final String name;
  final IconData icon;
  final String colorHex;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
  });

  CategoryModel copyWith({
    String? id,
    String? name,
    IconData? icon,
    String? colorHex,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  @override
  List<Object?> get props => [id, name, icon, colorHex];

  /// Predefined expense categories
  static const CategoryModel food = CategoryModel(
    id: 'food',
    name: 'Food',
    icon: Icons.restaurant_rounded,
    colorHex: '#FF6B6B',
  );

  static const CategoryModel travel = CategoryModel(
    id: 'travel',
    name: 'Travel',
    icon: Icons.flight_rounded,
    colorHex: '#4ECDC4',
  );

  static const CategoryModel accommodation = CategoryModel(
    id: 'accommodation',
    name: 'Accommodation',
    icon: Icons.hotel_rounded,
    colorHex: '#45B7D1',
  );

  static const CategoryModel entertainment = CategoryModel(
    id: 'entertainment',
    name: 'Entertainment',
    icon: Icons.movie_rounded,
    colorHex: '#FFA07A',
  );

  static const CategoryModel shopping = CategoryModel(
    id: 'shopping',
    name: 'Shopping',
    icon: Icons.shopping_bag_rounded,
    colorHex: '#DDA0DD',
  );

  static const CategoryModel utilities = CategoryModel(
    id: 'utilities',
    name: 'Utilities',
    icon: Icons.lightbulb_rounded,
    colorHex: '#FFD93D',
  );

  static const CategoryModel medical = CategoryModel(
    id: 'medical',
    name: 'Medical',
    icon: Icons.local_hospital_rounded,
    colorHex: '#6BCB77',
  );

  static const CategoryModel education = CategoryModel(
    id: 'education',
    name: 'Education',
    icon: Icons.school_rounded,
    colorHex: '#4D96FF',
  );

  static const CategoryModel other = CategoryModel(
    id: 'other',
    name: 'Other',
    icon: Icons.category_rounded,
    colorHex: '#95A5A6',
  );

  /// Get all predefined categories
  static List<CategoryModel> get all => [
        food,
        travel,
        accommodation,
        entertainment,
        shopping,
        utilities,
        medical,
        education,
        other,
      ];

  /// Get category by ID
  static CategoryModel? fromId(String id) {
    try {
      return all.firstWhere((cat) => cat.id == id);
    } catch (e) {
      return other;
    }
  }
}
