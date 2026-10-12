import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Mensajes breves en la parte inferior que desaparecen solos.
abstract final class AppSnackbar {
  /// Mensaje de éxito en verde, por ejemplo "Gasto guardado".
  static void success(BuildContext context, String message) =>
      _show(context, message, AppColors.success, Icons.check_circle_outline);

  /// Mensaje de error en rojo.
  static void error(BuildContext context, String message) =>
      _show(context, message, AppColors.error, Icons.error_outline);

  static void _show(
    BuildContext context,
    String message,
    Color background,
    IconData icon,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: background,
          content: Row(
            children: [
              Icon(icon, size: AppSizes.iconMd, color: AppColors.surface),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
