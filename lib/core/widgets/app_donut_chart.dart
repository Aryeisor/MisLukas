import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Porción de [AppDonutChart].
class AppChartSegment {
  const AppChartSegment({
    required this.value,
    required this.color,
    required this.label,
  });

  /// Valor de la porción; el ángulo es proporcional a value / suma.
  final int value;
  final Color color;

  /// Descripción para lectores de pantalla, por ejemplo "Mercado 38%".
  final String label;
}

/// Gráfico de dona dibujado con CustomPainter, con un contenido opcional en
/// el centro ("Total · Sep 2026").
class AppDonutChart extends StatelessWidget {
  const AppDonutChart({
    super.key,
    required this.segments,
    this.center,
    this.size = AppSizes.donutSize,
    this.strokeWidth = AppSizes.donutStroke,
    this.semanticsPrefix = 'Gráfico de dona',
  });

  final List<AppChartSegment> segments;
  final Widget? center;
  final double size;
  final double strokeWidth;

  /// Inicio de la descripción para lectores de pantalla.
  final String semanticsPrefix;

  @override
  Widget build(BuildContext context) {
    final description = segments.map((s) => s.label).join(', ');

    return Semantics(
      container: true,
      image: true,
      label: '$semanticsPrefix. $description',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _DonutPainter(
              segments: segments,
              strokeWidth: strokeWidth,
            ),
            child: center == null
                ? null
                : Center(
                    // Margen extra para que el texto no toque el anillo.
                    child: Padding(
                      padding: EdgeInsets.all(strokeWidth + AppSpacing.sm),
                      child: FittedBox(fit: BoxFit.scaleDown, child: center),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.segments, required this.strokeWidth});

  final List<AppChartSegment> segments;
  final double strokeWidth;

  // Separación entre porciones, en radianes.
  static const double _gap = 0.04;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - strokeWidth) / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final total = segments.fold<int>(0, (sum, s) => sum + math.max(0, s.value));
    if (total <= 0) {
      canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = AppColors.border);
      return;
    }

    final visible = segments.where((s) => s.value > 0).toList();
    final gap = visible.length > 1 ? _gap : 0.0;
    // Empieza arriba (−90°) y avanza en el sentido de las agujas del reloj.
    var start = -math.pi / 2;
    for (final segment in visible) {
      final sweep = 2 * math.pi * segment.value / total;
      final drawn = math.max(0.0, sweep - gap);
      canvas.drawArc(rect, start + gap / 2, drawn, false, paint..color = segment.color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.strokeWidth != strokeWidth;
}
