import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/theme/category_mapping.dart';
import '../../../core/theme/category_style.dart';
import '../../../core/utils/validators.dart';
import '../../movements/presentation/confirm_movement_view_model.dart';
import '../data/budgets_providers.dart';
import '../domain/usecases/watch_budget_overview.dart';

/// Presupuestos del mes actual para cada categoría de gasto, con lo gastado.
final budgetOverviewProvider = StreamProvider.autoDispose<List<BudgetLine>>(
  (ref) => ref.watch(watchBudgetOverviewProvider).call(),
);

/// Estado inmutable de la edición en Presupuestos: qué categoría se edita y
/// el límite escrito. Una sola a la vez.
class BudgetEditorState {
  const BudgetEditorState({this.editing, this.draft, this.isSaving = false});

  final CategoryKind? editing;
  final int? draft;

  /// Hay un guardado o una eliminación en curso.
  final bool isSaving;

  /// Guardar requiere un límite mayor que cero (RF-20).
  bool get canSave => editing != null && isValidAmount(draft) && !isSaving;
}

/// Resultado de guardar o quitar: null si salió bien; si no, el mensaje para
/// el usuario.
typedef BudgetEditorResult = String?;

final budgetEditorViewModelProvider =
    NotifierProvider.autoDispose<BudgetEditorViewModel, BudgetEditorState>(
      BudgetEditorViewModel.new,
    );

/// ViewModel de la edición de presupuestos (RF-52). Usa los mismos casos de
/// uso que la bienvenida: SetBudget valida el límite y la categoría.
class BudgetEditorViewModel extends Notifier<BudgetEditorState> {
  @override
  BudgetEditorState build() => const BudgetEditorState();

  /// Abre la tarjeta de [category] con su límite actual (null si no tiene).
  void startEditing(CategoryKind category, int? currentLimit) {
    if (state.isSaving || !expenseCategoryOptions.contains(category)) return;
    state = BudgetEditorState(editing: category, draft: currentLimit);
  }

  void cancel() {
    if (state.isSaving) return;
    state = const BudgetEditorState();
  }

  void setDraft(int? limit) {
    if (state.editing == null) return;
    state = BudgetEditorState(
      editing: state.editing,
      draft: limit,
      isSaving: state.isSaving,
    );
  }

  /// Crea o actualiza el presupuesto del mes de la categoría que se edita.
  Future<BudgetEditorResult> save() async {
    final category = state.editing;
    if (category == null || !state.canSave) return dataSaveErrorMessage;
    final limit = state.draft;
    return _run(
      () => ref
          .read(setBudgetProvider)
          .call(categoryId: category.categoryId, limitAmount: limit),
    );
  }

  /// Quita el presupuesto [budgetId] (borrado lógico).
  Future<BudgetEditorResult> remove(String budgetId) async {
    if (state.isSaving) return dataSaveErrorMessage;
    return _run(() => ref.read(removeBudgetProvider).call(budgetId));
  }

  /// Ejecuta [action] marcando el estado como guardando; al terminar bien,
  /// cierra la edición. No registra el error en logs (docs/08 §8.8.5).
  Future<BudgetEditorResult> _run(Future<void> Function() action) async {
    final current = state;
    state = BudgetEditorState(
      editing: current.editing,
      draft: current.draft,
      isSaving: true,
    );
    try {
      await action();
      if (ref.mounted) state = const BudgetEditorState();
      return null;
    } catch (error) {
      if (ref.mounted) {
        state = BudgetEditorState(
          editing: current.editing,
          draft: current.draft,
        );
      }
      return userMessageFor(error);
    }
  }
}
