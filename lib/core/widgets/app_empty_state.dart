import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_primary_button.dart';

/// Estado vacío para listas: ícono, título, descripción y acción opcional.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Container(
              width: AppSizes.iconBoxLg,
              height: AppSizes.iconBoxLg,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: AppSizes.iconXl, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: textTheme.titleMedium, textAlign: TextAlign.center),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              description!,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
