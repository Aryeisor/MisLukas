import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';

/// Ajuste con interruptor: ícono, título, descripción opcional e interruptor
/// a la derecha ("Notificaciones de presupuesto"). Toda la tarjeta lo cambia.
class AppSwitchTile extends StatelessWidget {
  const AppSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;

  /// Null deshabilita el interruptor.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onChanged = this.onChanged;
    return MergeSemantics(
      child: AppCard(
        onTap: onChanged == null ? null : () => onChanged(!value),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleSmall),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs / 2),
                    Text(
                      subtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
