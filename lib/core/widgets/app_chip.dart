import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Chip seleccionable: activo con fondo azul claro y borde azul.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      // Área táctil mínima de 48 dp aunque el chip se vea más pequeño.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primaryLight,
      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: selected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.border,
        width: selected ? AppSizes.borderWidthSelected : AppSizes.borderWidth,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    );
  }
}

/// Grupo de [AppChip] de selección única.
class AppChipGroup<T> extends StatelessWidget {
  const AppChipGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  final List<T> options;
  final T? selected;
  final String Function(T option) labelBuilder;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final option in options)
          AppChip(
            label: labelBuilder(option),
            selected: option == selected,
            // Tocar el chip activo no lo deselecciona: siempre hay uno elegido.
            onSelected: (isSelected) {
              if (isSelected) onSelected(option);
            },
          ),
      ],
    );
  }
}
