import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Variante de color de [AppBanner].
enum AppBannerVariant { warning, success, error, info }

/// Franja con ícono, título y descripción opcional.
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.title,
    this.description,
    this.variant = AppBannerVariant.info,
    this.icon,
  });

  final String title;
  final String? description;
  final AppBannerVariant variant;

  /// Reemplaza el ícono por defecto de la variante.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (background, border, foreground, defaultIcon) = switch (variant) {
      AppBannerVariant.warning => (
        AppColors.warningBackground,
        AppColors.warningBorder,
        AppColors.warningText,
        Icons.warning_amber_rounded,
      ),
      AppBannerVariant.success => (
        AppColors.successLight,
        AppColors.successBorder,
        AppColors.success,
        Icons.check_circle_outline,
      ),
      AppBannerVariant.error => (
        AppColors.errorLight,
        AppColors.errorBorder,
        AppColors.error,
        Icons.error_outline,
      ),
      AppBannerVariant.info => (
        AppColors.primaryLight,
        AppColors.infoBorder,
        AppColors.primary,
        Icons.info_outline,
      ),
    };

    return Semantics(
      container: true,
      liveRegion: variant == AppBannerVariant.error,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? defaultIcon, size: AppSizes.iconMd, color: foreground),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: AppSpacing.xs / 2),
                    Text(
                      description!,
                      style: textTheme.bodySmall?.copyWith(color: foreground),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
