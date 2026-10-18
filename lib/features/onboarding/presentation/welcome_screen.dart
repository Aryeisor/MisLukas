import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/widgets/auth_flow_scaffold.dart';
import '../../budgets/presentation/notification_permission_flow.dart';
import '../../budgets/presentation/widgets/budget_limit_field.dart';
import '../../movements/presentation/confirm_movement_view_model.dart';
import '../../movements/presentation/widgets/income_form_fields.dart';
import 'welcome_controller.dart';
import 'welcome_view_model.dart';

/// Bienvenida para usuarios nuevos (pantalla 11, RF-51): ingresos del mes y,
/// opcionalmente, presupuestos por categoría.
///
/// Terminar u Omitir el paso 2 la marca como completada. Volver en el paso 2
/// regresa al paso 1; en el paso 1, cierra la bienvenida y también la marca.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final savedSomething = ref.read(welcomeViewModelProvider).savedSomething;
    await ref.read(welcomeControllerProvider.notifier).complete();
    if (!context.mounted) return;
    if (savedSomething) {
      AppSnackbar.success(
        context,
        'Listo, ya puedes ver tu disponible del mes',
      );
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  void _back(BuildContext context, WidgetRef ref) {
    final state = ref.read(welcomeViewModelProvider);
    if (state.isSaving) return;
    if (state.step == WelcomeStep.budgets) {
      ref.read(welcomeViewModelProvider.notifier).backToIncomes();
    } else {
      _finish(context, ref);
    }
  }

  Future<void> _saveIncomes(BuildContext context, WidgetRef ref) async {
    final error = await ref
        .read(welcomeViewModelProvider.notifier)
        .saveIncomes();
    if (error != null && context.mounted) AppSnackbar.error(context, error);
  }

  Future<void> _saveBudgets(BuildContext context, WidgetRef ref) async {
    final error = await ref
        .read(welcomeViewModelProvider.notifier)
        .saveBudgets();
    if (!context.mounted) return;
    if (error != null) {
      AppSnackbar.error(context, error);
      return;
    }
    // Con el primer presupuesto, las alertas empiezan a tener sentido.
    await maybeAskNotificationPermission(context, ref);
    if (!context.mounted) return;
    await _finish(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(welcomeViewModelProvider);
    final isIncomes = state.step == WelcomeStep.incomes;

    return PopScope(
      // Atrás del sistema hace lo mismo que Volver.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back(context, ref);
      },
      child: AuthFlowScaffold(
        // La clave separa los pasos: cada uno arranca con su desplazamiento.
        key: ValueKey(state.step),
        stepLabel: isIncomes ? 'Paso 1 de 2' : 'Paso 2 de 2',
        title: isIncomes
            ? '¿Con cuánto dinero cuentas este mes?'
            : 'Define tus presupuestos',
        description: isIncomes
            ? 'Registra tus ingresos para ver cuánto tienes disponible. '
                  'Puedes cambiarlos después.'
            : 'Opcional. Te avisaremos al llegar al 75% y al 100% de cada '
                  'uno.',
        onBack: () => _back(context, ref),
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppPrimaryButton(
              label: isIncomes ? 'Continuar' : 'Guardar presupuestos',
              isLoading: state.isSaving,
              onPressed: isIncomes
                  ? (state.canContinue
                        ? () => _saveIncomes(context, ref)
                        : null)
                  : (state.canSaveBudgets
                        ? () => _saveBudgets(context, ref)
                        : null),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppSecondaryButton(
              label: 'Omitir',
              onPressed: state.isSaving
                  ? null
                  : isIncomes
                  ? ref.read(welcomeViewModelProvider.notifier).skipIncomes
                  : () => _finish(context, ref),
            ),
          ],
        ),
        children: isIncomes
            ? _incomes(context, ref, state)
            : _budgets(context, ref, state),
      ),
    );
  }

  List<Widget> _incomes(
    BuildContext context,
    WidgetRef ref,
    WelcomeState state,
  ) {
    final viewModel = ref.read(welcomeViewModelProvider.notifier);
    return [
      for (final (index, income) in state.incomes.indexed) ...[
        if (index > 0) const SizedBox(height: AppSpacing.lg),
        IncomeFormFields(
          key: ValueKey(income.key),
          amount: income.amount,
          onAmountChanged: (amount) =>
              viewModel.setIncomeAmount(income.key, amount),
          description: income.description,
          onDescriptionChanged: (description) =>
              viewModel.setIncomeDescription(income.key, description),
          trailing: index == 0
              ? null
              : AppIconButton(
                  icon: Icons.close,
                  tooltip: 'Quitar ingreso',
                  onPressed: state.isSaving
                      ? null
                      : () => viewModel.removeIncome(income.key),
                ),
        ),
      ],
      if (state.canAddIncome) ...[
        const SizedBox(height: AppSpacing.lg),
        AppSecondaryButton(
          label: 'Agregar otro ingreso',
          icon: Icons.add,
          onPressed: viewModel.addIncome,
        ),
      ],
    ];
  }

  List<Widget> _budgets(
    BuildContext context,
    WidgetRef ref,
    WelcomeState state,
  ) {
    final viewModel = ref.read(welcomeViewModelProvider.notifier);
    return [
      for (final (index, category) in expenseCategoryOptions.indexed) ...[
        if (index > 0) const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BudgetCategoryHeader(category: category),
              const SizedBox(height: AppSpacing.md),
              BudgetLimitField(
                key: ValueKey(category),
                category: category,
                initialValue: state.budgets[category],
                onChanged: (limit) => viewModel.setBudget(category, limit),
              ),
            ],
          ),
        ),
      ],
    ];
  }
}
