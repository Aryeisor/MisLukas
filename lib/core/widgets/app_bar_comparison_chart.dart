import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_legend_item.dart';

/// Grupo de [AppBarComparisonChart]: una etiqueta ("A1") y dos valores.
class AppBarGroup {
  const AppBarGroup({
    required this.label,
    required this.secondary,
    required this.primary,
    required this.semanticLabel,
  });

  final String label;

  /// Valor de la serie de referencia (gris), por ejemplo sin interés.
  final int secondary;

  /// Valor de la serie destacada (azul), por ejemplo con interés.
  final int primary;

  /// Descripción del grupo para lectores de pantalla.
  final String semanticLabel;
}

/// Barras verticales agrupadas que comparan dos series, dibujadas con
/// CustomPainter, con leyenda debajo. Si las etiquetas no caben, se muestra
/// una cada cierto número de grupos para que no se encimen.
class AppBarComparisonChart extends StatelessWidget {
  const AppBarComparisonChart({
    super.key,
    required this.groups,
    required this.secondaryLabel,
    required this.primaryLabel,
    this.secondaryColor = AppColors.disabled,
    this.primaryColor = AppColors.primary,
    this.height = AppSizes.chartHeight,
  });

  final List<AppBarGroup> groups;
  final String secondaryLabel;
  final String primaryLabel;
  final Color secondaryColor;
  final Color primaryColor;

  /// Alto del área de las barras, sin contar las etiquetas.
  final double height;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodySmall!;
    final textScaler = MediaQuery.textScalerOf(context);
    final labelHeight = (TextPainter(
      text: TextSpan(text: 'A', style: labelStyle),
      textScaler: textScaler,
      textDirection: TextDirection.ltr,
    )..layout()).height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          image: true,
          label: groups.map((g) => g.semanticLabel).join('; '),
          child: ExcludeSemantics(
            child: SizedBox(
              height: height + AppSpacing.sm + labelHeight,
              width: double.infinity,
              child: CustomPaint(
                painter: _BarComparisonPainter(
                  groups: groups,
                  secondaryColor: secondaryColor,
                  primaryColor: primaryColor,
                  barsHeight: height,
                  labelStyle: labelStyle,
                  textScaler: textScaler,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.xs,
          children: [
            AppLegendItem(
              color: secondaryColor,
              label: secondaryLabel,
              shape: AppLegendShape.square,
            ),
            AppLegendItem(
              color: primaryColor,
              label: primaryLabel,
              shape: AppLegendShape.square,
            ),
          ],
        ),
      ],
    );
  }
}

class _BarComparisonPainter extends CustomPainter {
  _BarComparisonPainter({
    required this.groups,
    required this.secondaryColor,
    required this.primaryColor,
    required this.barsHeight,
    required this.labelStyle,
    required this.textScaler,
  });

  final List<AppBarGroup> groups;
  final Color secondaryColor;
  final Color primaryColor;
  final double barsHeight;
  final TextStyle labelStyle;
  final TextScaler textScaler;

  // Ancho máximo de cada barra y separación entre las dos de un grupo.
  static const double _maxBarWidth = 28;
  static const double _barGap = 4;

  // Proporción del espacio de cada grupo que ocupan sus barras.
  static const double _groupFill = 0.7;

  // Espacio mínimo entre etiquetas del eje.
  static const double _minLabelGap = AppSpacing.sm;

  @override
  void paint(Canvas canvas, Size size) {
    if (groups.isEmpty) return;

    final slot = size.width / groups.length;
    final barWidth = math.max(
      1.0,
      math.min(_maxBarWidth, (slot * _groupFill - _barGap) / 2),
    );
    final maxValue = groups
        .expand((g) => [g.secondary, g.primary])
        .fold<int>(0, math.max);

    final labels = [
      for (final group in groups)
        TextPainter(
          text: TextSpan(text: group.label, style: labelStyle),
          textScaler: textScaler,
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final widestLabel = labels.map((l) => l.width).fold<double>(0, math.max);
    // Cada cuántos grupos se dibuja una etiqueta para que no se encimen.
    final step = math.max(1, ((widestLabel + _minLabelGap) / slot).ceil());

    final radius = Radius.circular(math.min(barWidth / 4, AppRadius.sm / 2));
    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      final centerX = slot * i + slot / 2;
      final secondaryLeft = centerX - _barGap / 2 - barWidth;
      final primaryLeft = centerX + _barGap / 2;

      _drawBar(canvas, secondaryLeft, barWidth, group.secondary, maxValue,
          secondaryColor, radius);
      _drawBar(canvas, primaryLeft, barWidth, group.primary, maxValue,
          primaryColor, radius);

      // La última etiqueta siempre se muestra; las demás, cada [step] grupos.
      if ((groups.length - 1 - i) % step == 0) {
        final label = labels[i];
        final x = (centerX - label.width / 2)
            .clamp(0.0, math.max(0.0, size.width - label.width))
            .toDouble();
        label.paint(canvas, Offset(x, barsHeight + AppSpacing.sm));
      }
    }
  }

  void _drawBar(
    Canvas canvas,
    double left,
    double width,
    int value,
    int maxValue,
    Color color,
    Radius radius,
  ) {
    if (maxValue <= 0 || value <= 0) return;
    final barHeight = barsHeight * value / maxValue;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(left, barsHeight - barHeight, width, barHeight),
        topLeft: radius,
        topRight: radius,
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_BarComparisonPainter oldDelegate) =>
      oldDelegate.groups != groups ||
      oldDelegate.secondaryColor != secondaryColor ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.barsHeight != barsHeight ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.textScaler != textScaler;
}
