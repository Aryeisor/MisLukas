import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Aviso discreto que se muestra en la parte superior cuando no hay conexión.
class AppOfflineIndicator extends StatelessWidget {
  const AppOfflineIndicator({super.key});

  static const String message =
      'Sin conexión. Tus cambios se guardarán en el celular';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        color: AppColors.surfaceMuted,
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: AppSizes.iconSm,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
