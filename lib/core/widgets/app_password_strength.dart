import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/validators.dart';

/// Requisito de contraseña con su estado.
class AppRequirement {
  const AppRequirement({required this.label, required this.met});

  final String label;
  final bool met;
}

/// Indicador de fortaleza (barra y Débil/Media/Fuerte) y lista de requisitos
/// que se marcan en verde al cumplirse. Además del color, cambia el ícono.
class AppPasswordStrength extends StatelessWidget {
  const AppPasswordStrength({
    super.key,
    required this.strength,
    required this.requirements,
  });

  final PasswordStrength strength;
  final List<AppRequirement> requirements;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (label, color, progress) = switch (strength) {
      PasswordStrength.weak => ('Débil', AppColors.error, 1 / 3),
      PasswordStrength.medium => ('Media', AppColors.warning, 2 / 3),
      PasswordStrength.strong => ('Fuerte', AppColors.success, 1.0),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // La barra es visual; el lector de pantalla lee la etiqueta.
            Expanded(
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: AppSizes.progressBarHeight,
                    color: color,
                    backgroundColor: AppColors.border,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              semanticsLabel: 'Fortaleza de la contraseña: $label',
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: strength == PasswordStrength.medium
                    ? AppColors.warningText
                    : color,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final requirement in requirements)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs / 2),
            child: MergeSemantics(
              child: Row(
                children: [
                  Icon(
                    requirement.met
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: AppSizes.iconSm,
                    color: requirement.met
                        ? AppColors.success
                        : AppColors.textSecondary,
                    semanticLabel: requirement.met ? 'Cumplido' : 'Pendiente',
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      requirement.label,
                      style: textTheme.bodySmall?.copyWith(
                        color: requirement.met
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
