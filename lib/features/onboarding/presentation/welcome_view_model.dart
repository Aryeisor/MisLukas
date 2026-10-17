import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/domain_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/theme/category_mapping.dart';
import '../../../core/theme/category_style.dart';
import '../../../core/utils/validators.dart';
import '../../budgets/data/budgets_providers.dart';
import '../../movements/data/movements_providers.dart';
import '../../movements/presentation/confirm_movement_view_model.dart';

/// Máximo de ingresos en el paso 1.
const int welcomeMaxIncomes = 5;

/// Descripción del primer ingreso de la bienvenida.
const String welcomeDefaultIncomeDescription = 'Salario';

/// Paso de la bienvenida.
enum WelcomeStep { incomes, budgets }

/// Ingreso escrito en el paso 1. [movementId] es el del movimiento ya
/// guardado: al volver del paso 2 y continuar de nuevo, se actualiza en vez de
/// crear otro.
class WelcomeIncomeDraft {
  const WelcomeIncomeDraft({
    required this.key,
    this.amount,
    this.description = '',
    this.movementId,
  });

  /// Identifica la tarjeta en la pantalla (no cambia al quitar otras).
  final int key;
  final int? amount;
  final String description;
  final String? movementId;

  WelcomeIncomeDraft copyWith({
    int? Function()? amount,
    String? description,
    String? movementId,
  }) {
    return WelcomeIncomeDraft(
      key: key,
      amount: amount != null ? amount() : this.amount,
      description: description ?? this.description,
      movementId: movementId ?? this.movementId,
    );
  }
}

/// Estado inmutable de la bienvenida.
class WelcomeState {
  const WelcomeState({
    this.step = WelcomeStep.incomes,
    required this.incomes,
    this.removedMovementIds = const [],
    this.budgets = const {},
    this.isSaving = false,
  });

  final WelcomeStep step;
  final List<WelcomeIncomeDraft> incomes;

  /// Ingresos ya guardados que el usuario quitó: se eliminan al continuar.
  final List<String> removedMovementIds;

  /// Límite escrito por categoría de gasto; null si está vacío.
  final Map<CategoryKind, int?> budgets;
  final bool isSaving;

  bool get canAddIncome => incomes.length < welcomeMaxIncomes && !isSaving;

  /// Continuar requiere un valor mayor que cero en cada ingreso.
  bool get canContinue =>
      !isSaving && incomes.every((income) => isValidAmount(income.amount));

  /// Límites escritos (los vacíos no cuentan).
  Map<CategoryKind, int> get filledBudgets => {
    for (final entry in budgets.entries)
      if (entry.value != null) entry.key: entry.value!,
  };

  /// Guardar requiere al menos un límite y que todos los escritos sean
  /// mayores que cero.
  bool get canSaveBudgets {
    final filled = filledBudgets;
    return !isSaving &&
        filled.isNotEmpty &&
        filled.values.every((limit) => isValidAmount(limit));
  }

  /// Se guardó al menos un ingreso o un presupuesto.
  bool get savedSomething => incomes.any((i) => i.movementId != null);

  WelcomeState copyWith({
    WelcomeStep? step,
    List<WelcomeIncomeDraft>? incomes,
    List<String>? removedMovementIds,
    Map<CategoryKind, int?>? budgets,
    bool? isSaving,
  }) {
    return WelcomeState(
      step: step ?? this.step,
      incomes: incomes ?? this.incomes,
      removedMovementIds: removedMovementIds ?? this.removedMovementIds,
      budgets: budgets ?? this.budgets,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

/// Resultado de guardar: null si salió bien; si no, el mensaje para el
/// usuario.
typedef WelcomeResult = String?;

final welcomeViewModelProvider =
    NotifierProvider.autoDispose<WelcomeViewModel, WelcomeState>(
      WelcomeViewModel.new,
    );

/// ViewModel de la bienvenida (RF-51). Los ingresos se guardan con el mismo
/// caso de uso que Nuevo movimiento (RegisterIncome) y los presupuestos con
/// SetBudget. No registra errores en logs: pueden incluir datos del usuario.
class WelcomeViewModel extends Notifier<WelcomeState> {
  int _nextKey = 1;

  @override
  WelcomeState build() => const WelcomeState(
    incomes: [
      WelcomeIncomeDraft(key: 0, description: welcomeDefaultIncomeDescription),
    ],
  );

  void _updateIncome(
    int key,
    WelcomeIncomeDraft Function(WelcomeIncomeDraft) change,
  ) {
    state = state.copyWith(
      incomes: [
        for (final income in state.incomes)
          income.key == key ? change(income) : income,
      ],
    );
  }

  void setIncomeAmount(int key, int? amount) =>
      _updateIncome(key, (i) => i.copyWith(amount: () => amount));

  void setIncomeDescription(int key, String description) =>
      _updateIncome(key, (i) => i.copyWith(description: description));

  void addIncome() {
    if (!state.canAddIncome) return;
    state = state.copyWith(
      incomes: [
        ...state.incomes,
        WelcomeIncomeDraft(key: _nextKey++),
      ],
    );
  }

  /// Quita un ingreso; el primero siempre queda.
  void removeIncome(int key) {
    if (state.isSaving || state.incomes.length <= 1) return;
    final removed = state.incomes.where((i) => i.key == key).firstOrNull;
    if (removed == null) return;
    state = state.copyWith(
      incomes: [
        for (final i in state.incomes)
          if (i.key != key) i,
      ],
      removedMovementIds: [
        ...state.removedMovementIds,
        if (removed.movementId != null) removed.movementId!,
      ],
    );
  }

  /// Omitir el paso 1: pasa a los presupuestos sin guardar ingresos.
  void skipIncomes() {
    if (state.isSaving) return;
    state = state.copyWith(step: WelcomeStep.budgets);
  }

  void backToIncomes() {
    if (state.isSaving) return;
    state = state.copyWith(step: WelcomeStep.incomes);
  }

  /// Guarda los ingresos y pasa al paso 2. Los ya guardados se actualizan y
  /// los quitados se eliminan, así que repetir no duplica nada.
  Future<WelcomeResult> saveIncomes() async {
    if (!state.canContinue) return dataSaveErrorMessage;
    state = state.copyWith(isSaving: true);
    try {
      for (final id in state.removedMovementIds) {
        try {
          await ref.read(deleteMovementProvider).call(id);
        } on DomainException catch (error) {
          // Ya no existe: no hay nada que eliminar.
          if (error.error != DomainError.movementNotFound) rethrow;
        }
        if (!ref.mounted) return null;
        state = state.copyWith(
          removedMovementIds: [
            for (final other in state.removedMovementIds)
              if (other != id) other,
          ],
        );
      }
      for (final income in state.incomes) {
        final description = income.description.trim();
        if (income.movementId == null) {
          final movement = await ref
              .read(registerIncomeProvider)
              .call(amount: income.amount, description: description);
          if (!ref.mounted) return null;
          _updateIncome(income.key, (i) => i.copyWith(movementId: movement.id));
        } else {
          await ref
              .read(updateMovementProvider)
              .call(
                id: income.movementId!,
                amount: income.amount,
                description: description,
              );
          if (!ref.mounted) return null;
        }
      }
      state = state.copyWith(step: WelcomeStep.budgets, isSaving: false);
      return null;
    } catch (error) {
      if (ref.mounted) state = state.copyWith(isSaving: false);
      return userMessageFor(error);
    }
  }

  void setBudget(CategoryKind category, int? limit) {
    if (!expenseCategoryOptions.contains(category)) return;
    state = state.copyWith(budgets: {...state.budgets, category: limit});
  }

  /// Guarda los presupuestos del mes actual. Guardar otra vez la misma
  /// categoría actualiza su límite (SetBudget), no crea otro.
  Future<WelcomeResult> saveBudgets() async {
    if (!state.canSaveBudgets) return dataSaveErrorMessage;
    state = state.copyWith(isSaving: true);
    try {
      for (final entry in state.filledBudgets.entries) {
        await ref
            .read(setBudgetProvider)
            .call(categoryId: entry.key.categoryId, limitAmount: entry.value);
        if (!ref.mounted) return null;
      }
      state = state.copyWith(isSaving: false);
      return null;
    } catch (error) {
      if (ref.mounted) state = state.copyWith(isSaving: false);
      return userMessageFor(error);
    }
  }
}
