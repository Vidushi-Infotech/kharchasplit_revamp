import 'package:flutter/material.dart';
import '../../models/category_model.dart';

/// Square colored tile with a category (or any) icon. An optional small
/// [badge] (e.g. the actor's avatar on Activity rows) sits on its corner.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
    this.badge,
  });

  factory CategoryTile.forCategory(
    CategoryModel category, {
    Key? key,
    double size = 44,
    Widget? badge,
  }) =>
      CategoryTile(
        key: key,
        icon: category.icon,
        color: colorFromHex(category.colorHex),
        size: size,
        badge: badge,
      );

  final IconData icon;
  final Color color;
  final double size;
  final Widget? badge;

  static Color colorFromHex(String hex) {
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    if (v == null) return const Color(0xFF8E9A98);
    return Color(hex.length <= 7 ? 0xFF000000 | v : v);
  }

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: size * 0.55),
    );
    if (badge == null) return tile;
    return SizedBox(
      width: size + 6,
      height: size + 6,
      child: Stack(
        children: [
          tile,
          Positioned(right: 0, bottom: 0, child: badge!),
        ],
      ),
    );
  }
}
