import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_badge.dart';

/// Tarjeta seleccionable con ícono, título, descripción, badge opcional
/// e indicador tipo radio. Seleccionada: borde azul y fondo azul claro.
class SelectableOptionCard extends StatelessWidget {
  const SelectableOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.border,
        width: selected ? AppSizes.borderWidthSelected : AppSizes.borderWidth,
      ),
    );

    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? AppColors.primaryLight : AppColors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: AppSizes.iconBox,
                  height: AppSizes.iconBox,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.surface
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    icon,
                    size: AppSizes.iconMd,
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(title, style: textTheme.titleMedium),
                          if (badge != null) AppBadge(label: badge!),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(description, style: textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: AppSizes.iconMd,
                  color: selected ? AppColors.primary : AppColors.disabled,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
