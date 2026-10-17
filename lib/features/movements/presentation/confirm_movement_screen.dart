import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/domain_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/category_style.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/utils_providers.dart';
import '../../../core/widgets/widgets.dart';
import 'confirm_movement_view_model.dart';
import 'movement_entry_method.dart';
import 'widgets/income_form_fields.dart';

/// Confirma los datos (foto), Registra tu gasto (manual) o Editar movimiento:
/// pantalla 7, fig. 5.6 y 5.7. Al editar un ingreso muestra su formulario
/// (valor, descripción y fecha). El ingreso nuevo se registra en Nuevo
/// movimiento.
class ConfirmMovementScreen extends ConsumerWidget {
  const ConfirmMovementScreen({super.key, required this.mode});

  final ConfirmMovementMode mode;

  bool get _isPhoto =>
      mode == const CreateMovementMode(MovementEntryMethod.photo);

  bool get _isEditing => mode is EditMovementMode;

  String get _title => _isEditing
      ? 'Editar movimiento'
      : _isPhoto
      ? 'Confirma los datos'
      : 'Registra tu gasto';

  /// Cierra la pantalla. Si se abrió sin historial (enlace directo), va a
  /// Inicio.
  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final error = await ref
        .read(confirmMovementViewModelProvider(mode).notifier)
        .save();
    if (!context.mounted) return;
    if (error != null) {
      AppSnackbar.error(context, error);
      return;
    }
    // El snackbar vive en el ScaffoldMessenger raíz y sigue visible en Inicio.
    if (_isEditing) {
      AppSnackbar.success(context, 'Cambios guardados');
      _close(context);
    } else {
      AppSnackbar.success(context, 'Gasto guardado');
      context.go(AppRoutes.home);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '¿Eliminar este movimiento?',
      message: 'Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final error = await ref
        .read(confirmMovementViewModelProvider(mode).notifier)
        .delete();
    if (!context.mounted) return;
    if (error != null) {
      AppSnackbar.error(context, error);
      return;
    }
    AppSnackbar.success(context, 'Movimiento eliminado');
    _close(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(confirmMovementViewModelProvider(mode));
    final state = async.value;
    final header = _Header(title: _title);

    final Widget body;
    if (async.hasError) {
      final error = async.error;
      body = ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          header,
          const SizedBox(height: AppSpacing.xl),
          AppBanner(
            variant: AppBannerVariant.error,
            title: 'No pudimos abrir este movimiento',
            description: error is DomainException
                ? userMessageFor(error)
                : dataLoadErrorMessage,
          ),
        ],
      );
    } else if (state == null) {
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: header,
          ),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    } else {
      body = _form(context, ref, state, header);
    }

    return Scaffold(
      // El cuerpo se reduce con el teclado: el botón queda encima de él y la
      // lista desplaza el campo activo para que siga visible.
      resizeToAvoidBottomInset: true,
      body: SafeArea(child: body),
    );
  }

  Widget _form(
    BuildContext context,
    WidgetRef ref,
    ConfirmMovementState state,
    Widget header,
  ) {
    final viewModel = ref.read(confirmMovementViewModelProvider(mode).notifier);
    final amountLabel = _isPhoto ? 'Valor detectado' : 'Valor del gasto';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              header,
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
              if (state.isIncome)
                IncomeFormFields(
                  amount: state.amount,
                  onAmountChanged: viewModel.setAmount,
                  description: state.description,
                  onDescriptionChanged: viewModel.setDescription,
                  date: state.date,
                  today: ref.watch(clockProvider).today(),
                  onDateChanged: viewModel.setDate,
                )
              else ...[
                AppCard(
                  child: AppAmountField(
                    label: amountLabel,
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
                        options: state.categoryOptions,
                        selected: state.category,
                        labelBuilder: (category) => category.label,
                        onSelected: viewModel.setCategory,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: _NoteField(
                    initialValue: state.note,
                    onChanged: viewModel.setNote,
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppPrimaryButton(
                label: _isEditing ? 'Guardar cambios' : 'Guardar gasto',
                icon: _isEditing ? Icons.check : Icons.description_outlined,
                isLoading: state.isSaving,
                onPressed: state.canSave ? () => _save(context, ref) : null,
              ),
              if (_isEditing) ...[
                const SizedBox(height: AppSpacing.sm),
                AppSecondaryButton(
                  label: 'Eliminar movimiento',
                  icon: Icons.delete_outline,
                  destructive: true,
                  onPressed: state.isSaving
                      ? null
                      : () => _delete(context, ref),
                ),
              ],
            ],
          ),
        ),
      ],
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
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
      ],
    );
  }
}

/// Nota opcional, precargada al editar.
class _NoteField extends StatefulWidget {
  const _NoteField({required this.initialValue, required this.onChanged});

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: 'Nota (opcional)',
      hint: 'Ej: mercado de la semana',
      controller: _controller,
      maxLength: movementNoteMaxLength,
      textInputAction: TextInputAction.done,
      onChanged: widget.onChanged,
    );
  }
}
