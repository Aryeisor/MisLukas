import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Tarjeta de resultado: etiqueta en mayúsculas, valor, descripción y un texto
/// destacado opcional ("SIN INTERÉS $15.120.000 Ahorro simple").
///
/// Con [highlighted] usa fondo y borde verdes, como "CON INTERÉS" del simulador.
class AppStatCard extends StatelessWidget {
  const AppStatCard({
    super.key,
    required this.label,
    required this.value,
    this.description,
    this.highlight,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final String? description;

  /// Texto en verde bajo la descripción, como "+$1.596.595 en intereses".
  final String? highlight;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = highlighted ? AppColors.success : AppColors.textSecondary;

    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.successLight : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: highlighted ? AppColors.successBorder : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(color: accent),
            ),
            const SizedBox(height: AppSpacing.sm),
            // El valor se reduce en tarjetas angostas en lugar de partirse.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(description!, style: textTheme.bodySmall),
            ],
            if (highlight != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                highlight!,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
