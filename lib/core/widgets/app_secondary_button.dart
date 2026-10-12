import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_badge.dart';

/// Botón secundario con borde, de ancho completo.
///
/// [badge] muestra una etiqueta pequeña debajo del botón, como "Próximamente".
class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.badge,
    this.badgeTone = AppBadgeTone.error,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? badge;
  final AppBadgeTone badgeTone;

  @override
  Widget build(BuildContext context) {
    final button = icon != null
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: AppSizes.iconMd),
            label: Text(label),
          )
        : OutlinedButton(onPressed: onPressed, child: Text(label));

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
