import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Dato secundario de [AppSummaryCard], como "↑ Ingresos $4.250.000".
class AppSummaryItem {
  const AppSummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

/// Tarjeta principal azul con un valor destacado (disponible del mes,
/// ahorro promedio) y datos secundarios opcionales debajo.
class AppSummaryCard extends StatelessWidget {
  const AppSummaryCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.items = const [],
  });

  final String label;
  final String value;

  /// Texto pequeño bajo el valor, por ejemplo "Calculado entre julio y septiembre".
  final String? caption;
  final List<AppSummaryItem> items;

  // Opacidad de los círculos decorativos.
  static const double _circleOpacity = 0.08;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final mutedStyle = textTheme.bodySmall?.copyWith(
      color: AppColors.primaryLight,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Círculos decorativos translúcidos en la esquina superior derecha.
          const Positioned(
            top: -AppSizes.decorCircleSm / 2,
            right: -AppSizes.decorCircleSm / 2,
            child: _DecorCircle(
              size: AppSizes.decorCircleLg,
              opacity: _circleOpacity,
            ),
          ),
          const Positioned(
            top: AppSizes.decorCircleSm / 2,
            right: AppSpacing.xl,
            child: _DecorCircle(
              size: AppSizes.decorCircleSm,
              opacity: _circleOpacity,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: mutedStyle),
                const SizedBox(height: AppSpacing.xs),
                // El valor se reduce en pantallas angostas en lugar de partirse.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    value,
                    style: textTheme.headlineLarge?.copyWith(
                      color: AppColors.surface,
                    ),
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(caption!, style: mutedStyle),
                ],
                if (items.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.lg),
                        Expanded(child: _SummaryItemView(item: items[i])),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItemView extends StatelessWidget {
  const _SummaryItemView({required this.item});

  final AppSummaryItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  item.icon,
                  size: AppSizes.iconSm,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  item.label,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              item.value,
              style: textTheme.titleMedium?.copyWith(
                color: AppColors.surface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorCircle extends StatelessWidget {
  const _DecorCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface.withValues(alpha: opacity),
      ),
    );
  }
}
