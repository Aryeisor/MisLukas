import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/category_style.dart';
import '../../../../core/widgets/widgets.dart';

/// Ícono y nombre de una categoría en la tarjeta de su presupuesto. Se usa en
/// la bienvenida (paso 2) y en Presupuestos.
class BudgetCategoryHeader extends StatelessWidget {
  const BudgetCategoryHeader({
    super.key,
    required this.category,
    this.trailing,
  });

  final CategoryKind category;

  /// Texto a la derecha, por ejemplo el porcentaje usado.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CategoryIcon(kind: category),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            category.label,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

/// Campo del límite mensual de una categoría ("LÍMITE MENSUAL DE MERCADO"):
/// solo dígitos, valor como int.
class BudgetLimitField extends StatelessWidget {
  const BudgetLimitField({
    super.key,
    required this.category,
    required this.initialValue,
    required this.onChanged,
  });

  final CategoryKind category;
  final int? initialValue;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppAmountField(
      label: 'Límite mensual de ${category.label.toLowerCase()}',
      initialValue: initialValue,
      onChanged: onChanged,
    );
  }
}
