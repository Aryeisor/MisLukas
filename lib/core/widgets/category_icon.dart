import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/category_style.dart';

/// Ícono de la categoría dentro de un cuadrado redondeado con su fondo pastel.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({super.key, required this.kind});

  final CategoryKind kind;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: kind.label,
      excludeSemantics: true,
      child: Container(
        width: AppSizes.iconBox,
        height: AppSizes.iconBox,
        decoration: BoxDecoration(
          color: kind.backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(kind.icon, size: AppSizes.iconMd, color: kind.color),
      ),
    );
  }
}
