import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Tono de color de [AppBadge].
enum AppBadgeTone { primary, error, neutral }

/// Etiqueta pequeña como "Recomendado" o "Próximamente".
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = AppBadgeTone.primary,
  });

  final String label;
  final AppBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    // El borde mantiene visible la pastilla sobre fondos del mismo tono,
    // como una SelectableOptionCard seleccionada (fondo primaryLight).
    final (background, border, foreground) = switch (tone) {
      AppBadgeTone.primary => (
        AppColors.primaryLight,
        AppColors.infoBorder,
        AppColors.primary,
      ),
      AppBadgeTone.error => (
        AppColors.errorLight,
        AppColors.errorBorder,
        AppColors.error,
      ),
      AppBadgeTone.neutral => (
        AppColors.surfaceMuted,
        AppColors.border,
        AppColors.textSecondary,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs / 2,
      ),
      decoration: ShapeDecoration(
        color: background,
        shape: StadiumBorder(side: BorderSide(color: border)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
