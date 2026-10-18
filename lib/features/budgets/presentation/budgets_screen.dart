import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/category_mapping.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/utils_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/entities/budget_alert.dart';
import '../domain/usecases/watch_budget_overview.dart';
import 'budgets_view_model.dart';
import 'notification_permission_flow.dart';
import 'widgets/budget_limit_field.dart';

/// Presupuestos del mes (RF-52, pantalla 13): gastado, límite y porcentaje de
/// cada categoría de gasto, y crear, editar o quitar cada presupuesto. Se abre
/// desde Perfil › Preferencias.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(budgetOverviewProvider);
    final textTheme = Theme.of(context).textTheme;
    final month = ref.watch(clockProvider).currentMonth();

    final List<Widget> content;
    if (lines.hasError) {
      content = const [
        AppBanner(
          variant: AppBannerVariant.error,
          title: 'No pudimos cargar tus presupuestos',
          description: dataLoadErrorMessage,
        ),
      ];
    } else if (lines.value == null) {
      content = const [
        Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    } else {
      content = [
        for (final (index, line) in lines.value!.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.md),
          _BudgetCard(key: ValueKey(line.categoryId), line: line),
        ],
      ];
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            Row(
              children: [
                AppIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Volver',
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go(AppRoutes.profile),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'Presupuestos',
                          style: textTheme.headlineSmall,
                        ),
                      ),
                      Text(
                        DateLabels.monthYear(month),
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Te avisaremos al llegar al 75% y al 100% de cada uno. Cada mes '
              'empieza con los límites del mes anterior.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            ...content,
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de una categoría: resumen del presupuesto o, al tocarla, el campo
/// del límite con Guardar, Cancelar y Quitar.
class _BudgetCard extends ConsumerWidget {
  const _BudgetCard({super.key, required this.line});

  final BudgetLine line;

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final error = await ref.read(budgetEditorViewModelProvider.notifier).save();
    if (!context.mounted) return;
    if (error != null) {
      AppSnackbar.error(context, error);
    } else {
      AppSnackbar.success(context, 'Presupuesto guardado');
      await maybeAskNotificationPermission(context, ref);
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final budget = line.budget;
    if (budget == null) return;
    final category = categoryKindForId(line.categoryId);
    final confirmed = await showAppConfirmDialog(
      context,
      title: '¿Quitar el presupuesto de ${category.label.toLowerCase()}?',
      message:
          'Dejarás de recibir alertas de esta categoría este mes. Puedes '
          'definirlo de nuevo cuando quieras.',
      confirmLabel: 'Quitar',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final error = await ref
        .read(budgetEditorViewModelProvider.notifier)
        .remove(budget.id);
    if (!context.mounted) return;
    if (error != null) {
      AppSnackbar.error(context, error);
    } else {
      AppSnackbar.success(context, 'Presupuesto quitado');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(budgetEditorViewModelProvider);
    final viewModel = ref.read(budgetEditorViewModelProvider.notifier);
    final category = categoryKindForId(line.categoryId);
    final isEditing = editor.editing == category;
    final budget = line.budget;
    final textTheme = Theme.of(context).textTheme;

    if (isEditing) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BudgetCategoryHeader(category: category),
            const SizedBox(height: AppSpacing.md),
            BudgetLimitField(
              category: category,
              initialValue: editor.draft,
              onChanged: viewModel.setDraft,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              label: 'Guardar',
              icon: Icons.check,
              isLoading: editor.isSaving,
              onPressed: editor.canSave ? () => _save(context, ref) : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppSecondaryButton(
              label: 'Cancelar',
              onPressed: editor.isSaving ? null : viewModel.cancel,
            ),
            if (budget != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppSecondaryButton(
                label: 'Quitar presupuesto',
                icon: Icons.delete_outline,
                destructive: true,
                onPressed: editor.isSaving ? null : () => _remove(context, ref),
              ),
            ],
          ],
        ),
      );
    }

    final percent = line.percent;
    final Widget details;
    if (budget == null) {
      details = Text(
        'Sin presupuesto. Toca para definirlo.',
        style: textTheme.bodySmall,
      );
    } else {
      final remaining = line.remaining;
      final status = remaining >= 0
          ? 'Te quedan ${CurrencyFormatter.format(remaining)}'
          : 'Superaste el límite por ${CurrencyFormatter.format(-remaining)}';
      details = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Gastado ${CurrencyFormatter.format(line.spent)} de '
            '${CurrencyFormatter.format(budget.limitAmount)}',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppVariationBar(
            fraction: line.spent / budget.limitAmount,
            color: _usageColor(percent),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('$percent% · $status', style: textTheme.bodySmall),
        ],
      );
    }

    return Semantics(
      hint: budget == null ? 'Toca para definirlo' : 'Toca para cambiarlo',
      child: AppCard(
        onTap: editor.isSaving
            ? null
            : () => viewModel.startEditing(category, budget?.limitAmount),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BudgetCategoryHeader(category: category),
            const SizedBox(height: AppSpacing.md),
            details,
          ],
        ),
      ),
    );
  }

  /// Azul bajo el 75%, amarillo desde el 75% y rojo desde el 100%. El texto
  /// lleva el porcentaje: el color no es la única señal.
  static Color _usageColor(int percent) {
    if (percent >= BudgetAlertThreshold.exceeded.percent) {
      return AppColors.error;
    }
    if (percent >= BudgetAlertThreshold.warning.percent) {
      return AppColors.warning;
    }
    return AppColors.primary;
  }
}
