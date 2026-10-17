import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/utils_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/entities/movement.dart';
import 'confirm_movement_view_model.dart';
import 'movement_entry_method.dart';
import 'new_movement_view_model.dart';
import 'widgets/income_form_fields.dart';

/// Pantalla de Nuevo movimiento (pantalla 6, fig. 5.5): el selector
/// Gasto | Ingreso y, para un gasto, el método de registro; para un ingreso,
/// su formulario (RF-50).
class NewMovementScreen extends ConsumerWidget {
  const NewMovementScreen({super.key, this.initialType = MovementType.expense});

  /// Tipo seleccionado al abrir la pantalla.
  final MovementType initialType;

  /// Opciones del selector, en el orden de [MovementType].
  static const List<String> typeLabels = ['Gasto', 'Ingreso'];

  static const ConfirmMovementMode _incomeMode = CreateIncomeMode();

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _saveIncome(BuildContext context, WidgetRef ref) async {
    final error = await ref
        .read(confirmMovementViewModelProvider(_incomeMode).notifier)
        .save();
    if (!context.mounted) return;
    if (error != null) {
      AppSnackbar.error(context, error);
      return;
    }
    // El snackbar vive en el ScaffoldMessenger raíz y sigue visible en Inicio.
    AppSnackbar.success(context, 'Ingreso guardado');
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = newMovementViewModelProvider(initialType);
    final selection = ref.watch(provider);
    final viewModel = ref.read(provider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final isIncome = selection.isIncome;
    final income = isIncome
        ? ref.watch(confirmMovementViewModelProvider(_incomeMode)).value
        : null;

    return Scaffold(
      // El cuerpo se reduce con el teclado: el botón queda encima de él.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                isIncome ? 'Nuevo ingreso' : 'Nuevo gasto',
                                style: textTheme.headlineSmall,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              isIncome
                                  ? '¿Cuánto dinero recibiste?'
                                  : '¿Cómo quieres registrarlo?',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      AppIconButton(
                        icon: Icons.close,
                        tooltip: 'Cerrar',
                        onPressed: () => _close(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Semantics(
                    container: true,
                    label: 'Tipo de movimiento',
                    child: AppSegmentedTabs(
                      labels: typeLabels,
                      selectedIndex: selection.type.index,
                      onChanged: (index) =>
                          viewModel.selectType(MovementType.values[index]),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (!isIncome) ...[
                    SelectableOptionCard(
                      icon: Icons.photo_camera_outlined,
                      title: MovementEntryMethod.photo.label,
                      badge: 'Recomendado',
                      description:
                          'La app extrae el valor y sugiere la categoría '
                          'automáticamente.',
                      selected: selection.method == MovementEntryMethod.photo,
                      onTap: () => viewModel.select(MovementEntryMethod.photo),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SelectableOptionCard(
                      icon: Icons.edit_outlined,
                      title: MovementEntryMethod.manual.label,
                      description:
                          'Escribe el valor y elige la categoría tú mismo.',
                      selected: selection.method == MovementEntryMethod.manual,
                      onTap: () => viewModel.select(MovementEntryMethod.manual),
                    ),
                  ] else if (income != null)
                    _IncomeForm(state: income, mode: _incomeMode)
                  else
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: isIncome
                  ? AppPrimaryButton(
                      label: 'Guardar ingreso',
                      icon: Icons.check,
                      isLoading: income?.isSaving ?? false,
                      onPressed: income?.canSave ?? false
                          ? () => _saveIncome(context, ref)
                          : null,
                    )
                  : AppPrimaryButton(
                      label: 'Continuar',
                      onPressed: () => context.push(
                        AppRoutes.confirmMovementWith(selection.method.name),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomeForm extends ConsumerWidget {
  const _IncomeForm({required this.state, required this.mode});

  final ConfirmMovementState state;
  final ConfirmMovementMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(confirmMovementViewModelProvider(mode).notifier);
    return IncomeFormFields(
      amount: state.amount,
      onAmountChanged: viewModel.setAmount,
      description: state.description,
      onDescriptionChanged: viewModel.setDescription,
      date: state.date,
      today: ref.watch(clockProvider).today(),
      onDateChanged: viewModel.setDate,
    );
  }
}
