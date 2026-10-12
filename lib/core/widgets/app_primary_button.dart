import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Botón de acción principal: fondo oscuro y ancho completo.
///
/// Deshabilitado cuando [onPressed] es null. Con [isLoading] muestra un
/// indicador de progreso y bloquea los toques sin cambiar a gris.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Semantics(
        label: '$label, cargando',
        excludeSemantics: true,
        child: FilledButton(
          onPressed: null,
          // Conserva el color oscuro mientras carga.
          style: FilledButton.styleFrom(
            disabledBackgroundColor: AppColors.action,
            disabledForegroundColor: AppColors.surface,
          ),
          child: const SizedBox.square(
            dimension: AppSizes.iconMd,
            child: CircularProgressIndicator(
              strokeWidth: AppSizes.progressStroke,
              color: AppColors.surface,
            ),
          ),
        ),
      );
    }

    if (icon != null) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: AppSizes.iconMd),
        label: Text(label),
      );
    }

    return FilledButton(onPressed: onPressed, child: Text(label));
  }
}
