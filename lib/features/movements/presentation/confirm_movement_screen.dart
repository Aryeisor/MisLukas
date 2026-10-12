import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/category_style.dart';
import '../../../core/widgets/widgets.dart';
import 'confirm_movement_view_model.dart';
import 'movement_entry_method.dart';

/// Confirma los datos (foto) o Registra tu gasto (manual): pantalla 7,
/// fig. 5.6 y 5.7.
class ConfirmMovementScreen extends ConsumerWidget {
  const ConfirmMovementScreen({super.key, required this.method});

  final MovementEntryMethod method;

  bool get _isPhoto => method == MovementEntryMethod.photo;

  void _save(BuildContext context, WidgetRef ref) {
    final saved = ref
        .read(confirmMovementViewModelProvider(method).notifier)
        .save();
    if (!saved) return;
    // El snackbar vive en el ScaffoldMessenger raíz y sigue visible en Inicio.
    AppSnackbar.success(context, 'Gasto guardado');
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = confirmMovementViewModelProvider(method);
    final state = ref.watch(provider);
    final viewModel = ref.read(provider.notifier);

    return Scaffold(
      // El cuerpo se reduce con el teclado: el botón queda encima de él y la
      // lista desplaza el campo activo para que siga visible.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  _Header(
                    title: _isPhoto ? 'Confirma los datos' : 'Registra tu gasto',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (_isPhoto) ...[
                    const AppBanner(
                      variant: AppBannerVariant.success,
                      title: 'Recibo leído correctamente',
                      description: 'Revisa y ajusta si necesitas.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ReceiptPreview(
                      merchant: demoReceiptHeader,
                      taxId: demoReceiptTaxId,
                      lines: [
                        for (final (label, amount) in demoReceiptItems)
                          ReceiptLine(label, amount),
                      ],
                      total: demoReceiptTotal,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  AppCard(
                    child: AppAmountField(
                      label: _isPhoto ? 'Valor detectado' : 'Valor del gasto',
                      initialValue: state.amount,
                      onChanged: viewModel.setAmount,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppFieldLabel(
                          _isPhoto ? 'Categoría sugerida' : 'Categoría',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppChipGroup<CategoryKind>(
                          options: expenseCategoryOptions,
                          selected: state.category,
                          labelBuilder: (category) => category.label,
                          onSelected: viewModel.setCategory,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    child: AppTextField(
                      label: 'Nota (opcional)',
                      hint: 'Ej: mercado de la semana',
                      maxLength: movementNoteMaxLength,
                      textInputAction: TextInputAction.done,
                      onChanged: viewModel.setNote,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: AppPrimaryButton(
                label: 'Guardar gasto',
                icon: Icons.description_outlined,
                onPressed: state.canSave ? () => _save(context, ref) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIconButton(
          icon: Icons.arrow_back,
          tooltip: 'Volver',
          onPressed: () => context.pop(),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
          ),
        ),
      ],
    );
  }
}
