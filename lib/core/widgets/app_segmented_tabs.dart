import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Selector de dos o más opciones sobre fondo gris claro;
/// la opción activa se resalta con fondo blanco.
class AppSegmentedTabs extends StatelessWidget {
  const AppSegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  }) : assert(labels.length >= 2, 'Se necesitan al menos dos opciones');

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selectedIndex,
                inMutuallyExclusiveGroup: true,
                child: Material(
                  color: i == selectedIndex
                      ? AppColors.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    onTap: () => onChanged(i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppSpacing.minTouchTarget,
                      ),
                      child: Center(
                        child: Text(
                          labels[i],
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: i == selectedIndex
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: i == selectedIndex
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
