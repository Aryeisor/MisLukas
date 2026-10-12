import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Categorías predeterminadas con su estilo visual (guía de estilo §5.4.1 y §5.4.3).
///
/// Es un mapeo de presentación: la entidad Categoría del dominio llega en la Fase 4.
enum CategoryKind {
  mercado('Mercado', AppColors.categoryMercado, Icons.shopping_cart_outlined),
  transporte(
    'Transporte',
    AppColors.categoryTransporte,
    Icons.directions_bus_outlined,
  ),
  ocio('Ocio', AppColors.categoryOcio, Icons.local_cafe_outlined),
  servicios('Servicios', AppColors.categoryServicios, Icons.lightbulb_outline),
  restaurantes(
    'Restaurantes',
    AppColors.categoryRestaurantes,
    Icons.restaurant_outlined,
  ),
  otros('Otros', AppColors.categoryOtros, Icons.more_horiz),
  ingreso('Ingreso', AppColors.categoryIngreso, Icons.arrow_upward_rounded);

  const CategoryKind(this.label, this.color, this.icon);

  /// Nombre visible para el usuario.
  final String label;

  /// Color propio de la categoría.
  final Color color;

  /// Ícono de línea de la categoría.
  final IconData icon;

  // Proporción del color de la categoría mezclada con blanco para el fondo pastel.
  static const double _backgroundTint = 0.12;

  /// Fondo pastel (opaco) derivado del color de la categoría.
  Color get backgroundColor =>
      Color.lerp(AppColors.surface, color, _backgroundTint)!;
}
