import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/category_style.dart';
import '../utils/currency_formatter.dart';
import 'app_card.dart';
import 'category_icon.dart';

/// Fila de un movimiento: ícono de categoría, nombre, "categoría · fecha"
/// y monto con signo (gasto en negro con "-", ingreso en verde con "+").
class MovementTile extends StatelessWidget {
  const MovementTile({
    super.key,
    required this.title,
    required this.category,
    required this.dateLabel,
    required this.amount,
    this.isPendingSync = false,
    this.onTap,
  });

  final String title;
  final CategoryKind category;

  /// Fecha ya formateada para mostrar, por ejemplo "Hoy" o "Sep 1".
  final String dateLabel;

  /// Monto en pesos, siempre positivo; el signo depende de la categoría.
  final int amount;

  /// Muestra el ícono de nube con reloj cuando el movimiento aún no se sincroniza.
  final bool isPendingSync;
  final VoidCallback? onTap;

  bool get _isIncome => category == CategoryKind.ingreso;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return MergeSemantics(
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CategoryIcon(kind: category),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs / 2),
                  Text(
                    '${category.label} · $dateLabel',
                    style: textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (isPendingSync) ...[
              const _PendingSyncIcon(),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(
              CurrencyFormatter.signed(amount, isIncome: _isIncome),
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: _isIncome ? AppColors.success : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nube con un reloj pequeño: el movimiento está pendiente de sincronizar.
class _PendingSyncIcon extends StatelessWidget {
  const _PendingSyncIcon();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Pendiente de sincronizar',
      child: Semantics(
        label: 'Pendiente de sincronizar',
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: AppSizes.iconMd,
          child: Stack(
            children: [
              const Align(
                alignment: Alignment.topLeft,
                child: Icon(
                  Icons.cloud_outlined,
                  size: AppSizes.iconSm,
                  color: AppColors.textSecondary,
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.schedule,
                    size: AppSizes.iconXs,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
