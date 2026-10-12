import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Barra horizontal con pista gris y relleno proporcional a [fraction] (0 a 1),
/// usada en la comparación mensual. Es decorativa: el texto que la acompaña
/// lleva el valor para lectores de pantalla.
class AppVariationBar extends StatelessWidget {
  const AppVariationBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = AppSizes.variationBarHeight,
  });

  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _VariationBarPainter(
            fraction: fraction.clamp(0.0, 1.0),
            color: color,
          ),
        ),
      ),
    );
  }
}

class _VariationBarPainter extends CustomPainter {
  _VariationBarPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = AppColors.surfaceMuted,
    );
    if (fraction <= 0) return;
    // Un mínimo del alto para que las variaciones pequeñas se vean.
    final width = (size.width * fraction).clamp(size.height, size.width);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & Size(width, size.height), radius),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_VariationBarPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color;
}
