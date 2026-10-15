import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_badge.dart';

/// Botón secundario con borde, de ancho completo.
///
/// [badge] muestra una etiqueta pequeña debajo del botón, como "Próximamente".
/// [destructive] pinta el texto y el borde en rojo para acciones como
/// "Eliminar movimiento".
class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.badge,
    this.badgeTone = AppBadgeTone.error,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? badge;
  final AppBadgeTone badgeTone;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final style = destructive
        ? OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: BorderSide(
              color: onPressed == null ? AppColors.border : AppColors.error,
            ),
          )
        : null;
    final button = icon != null
        ? OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: AppSizes.iconMd),
            label: Text(label),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: style,
            child: Text(label),
          );

    if (badge == null) return button;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: AppSpacing.sm),
        AppBadge(label: badge!, tone: badgeTone),
      ],
    );
  }
}
