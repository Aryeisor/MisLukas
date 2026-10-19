import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Ícono de moneda en un recuadro azul claro (login, desbloqueo y la capa de
/// recientes). Decorativo: el nombre va al lado o debajo.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: AppSizes.iconBoxLg,
        height: AppSizes.iconBoxLg,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Icon(
          Icons.attach_money_rounded,
          size: AppSizes.iconXl,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
