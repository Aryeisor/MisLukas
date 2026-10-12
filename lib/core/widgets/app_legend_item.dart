import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Forma de la muestra de color de [AppLegendItem].
enum AppLegendShape { dot, square }

/// Elemento de leyenda: muestra de color, etiqueta y un valor opcional a la
/// derecha ("● Mercado 38%", "■ Aumento").
///
/// Con [prominent] la etiqueta usa el texto del cuerpo en lugar del secundario.
class AppLegendItem extends StatelessWidget {
  const AppLegendItem({
    super.key,
    required this.color,
    required this.label,
    this.value,
    this.valueColor,
    this.shape = AppLegendShape.dot,
    this.prominent = false,
  });

  final Color color;
  final String label;
  final String? value;

  /// Color del valor; por defecto, el del texto principal.
  final Color? valueColor;
  final AppLegendShape shape;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDot = shape == AppLegendShape.dot;
    final swatch = Container(
      width: AppSizes.legendDot,
      height: AppSizes.legendDot,
      decoration: BoxDecoration(
        color: color,
        shape: isDot ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isDot
            ? null
            : BorderRadius.circular(AppSizes.legendDot / 4),
      ),
    );

    final labelText = Text(
      label,
      style: prominent ? textTheme.bodyMedium : textTheme.bodySmall,
    );

    return MergeSemantics(
      child: Row(
        mainAxisSize: value == null ? MainAxisSize.min : MainAxisSize.max,
        children: [
          swatch,
          const SizedBox(width: AppSpacing.sm),
          if (value == null)
            Flexible(child: labelText)
          else ...[
            Expanded(child: labelText),
            const SizedBox(width: AppSpacing.sm),
            Text(
              value!,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
