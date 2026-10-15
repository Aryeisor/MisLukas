import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/theme/category_mapping.dart';
import '../../../core/theme/category_style.dart';
import '../../../core/utils/validators.dart';
import '../data/movements_providers.dart';
import '../domain/entities/movement.dart';
import 'movement_entry_method.dart';

/// Máximo de caracteres de la nota.
const int movementNoteMaxLength = 200;

/// Categorías que se pueden elegir para un gasto. Incluye Otros (RF-27),
/// aunque el boceto 5.7 no la muestra.
const List<CategoryKind> expenseCategoryOptions = [
  CategoryKind.mercado,
  CategoryKind.transporte,
  CategoryKind.ocio,
  CategoryKind.servicios,
  CategoryKind.restaurantes,
  CategoryKind.otros,
];

/// Única categoría de un ingreso.
const List<CategoryKind> incomeCategoryOptions = [CategoryKind.ingreso];

/// Para qué se abre la pantalla: registrar un gasto nuevo o editar un
/// movimiento existente.
sealed class ConfirmMovementMode {
  const ConfirmMovementMode();
}

/// Registrar un gasto nuevo con [method].
class CreateMovementMode extends ConfirmMovementMode {
  const CreateMovementMode(this.method);

  final MovementEntryMethod method;

  @override
  bool operator ==(Object other) =>
      other is CreateMovementMode && other.method == method;

  @override
  int get hashCode => Object.hash(CreateMovementMode, method);
}

/// Editar el movimiento [movementId] (RF-23).
class EditMovementMode extends ConfirmMovementMode {
  const EditMovementMode(this.movementId);

  final String movementId;

  @override
  bool operator ==(Object other) =>
      other is EditMovementMode && other.movementId == movementId;

  @override
  int get hashCode => Object.hash(EditMovementMode, movementId);
}

/// Estado inmutable de Confirma los datos y de Editar movimiento.
class ConfirmMovementState {
  const ConfirmMovementState({
    required this.mode,
    this.amount,
    this.category,
    this.note = '',
    this.isIncome = false,
    this.isSaving = false,
  });

  final ConfirmMovementMode mode;
  final int? amount;
  final CategoryKind? category;
  final String note;

  /// El movimiento que se edita es un ingreso. Al editar no cambia el tipo.
  final bool isIncome;

  /// Hay un guardado o una eliminación en curso.
  final bool isSaving;

  bool get isEditing => mode is EditMovementMode;

  /// Categorías que se pueden elegir según el tipo del movimiento.
  List<CategoryKind> get categoryOptions =>
      isIncome ? incomeCategoryOptions : expenseCategoryOptions;

  /// Guardar requiere un valor mayor que cero y una categoría.
  bool get canSave => isValidAmount(amount) && category != null && !isSaving;

  ConfirmMovementState copyWith({
    int? Function()? amount,
    CategoryKind? category,
    String? note,
    bool? isSaving,
  }) {
    return ConfirmMovementState(
      mode: mode,
      amount: amount != null ? amount() : this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
      isIncome: isIncome,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

/// Resultado de guardar o eliminar: null si salió bien; si no, el mensaje
/// para el usuario.
typedef ConfirmMovementResult = String?;

// SOLO DEMO: datos que "leyó" el OCR en la variante foto (Fase 6 usa ML Kit).
const int demoReceiptTotal = 87400;
const CategoryKind demoReceiptCategory = CategoryKind.mercado;
const String demoReceiptMerchantName = 'Éxito';
const String demoReceiptHeader = 'ÉXITO AV. EL DORADO';
const String demoReceiptTaxId = '890.900.608-9';

/// Productos del recibo de la demo; suman [demoReceiptTotal].
const List<(String, int)> demoReceiptItems = [
  ('Leche larga vida x2', 8900),
  ('Pan tajado', 4500),
  ('Huevos x30', 19800),
  ('Aceite 900ml', 12400),
  ('Pollo pechugas', 23800),
  ('Arroz x5kg', 18000),
];

final confirmMovementViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<
      ConfirmMovementViewModel,
      ConfirmMovementState,
      ConfirmMovementMode
    >(ConfirmMovementViewModel.new);

class ConfirmMovementViewModel extends AsyncNotifier<ConfirmMovementState> {
  ConfirmMovementViewModel(this.mode);

  final ConfirmMovementMode mode;

  // Al registrar, el estado está listo de inmediato; al editar, primero se
  // carga el movimiento.
  @override
  FutureOr<ConfirmMovementState> build() {
    return switch (mode) {
      CreateMovementMode(method: MovementEntryMethod.photo) =>
        ConfirmMovementState(
          mode: mode,
          amount: demoReceiptTotal,
          category: demoReceiptCategory,
        ),
      CreateMovementMode(method: MovementEntryMethod.manual) =>
        ConfirmMovementState(mode: mode),
      EditMovementMode(:final movementId) => _load(movementId),
    };
  }

  Future<ConfirmMovementState> _load(String movementId) async {
    final movement = await ref.read(getMovementProvider).call(movementId);
    return ConfirmMovementState(
      mode: mode,
      amount: movement.amount,
      category: categoryKindForId(movement.categoryId),
      note: movement.note ?? '',
      isIncome: movement.isIncome,
    );
  }

  void _update(ConfirmMovementState Function(ConfirmMovementState) change) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(change(current));
  }

  void setAmount(int? amount) =>
      _update((s) => s.copyWith(amount: () => amount));

  void setCategory(CategoryKind category) {
    final current = state.value;
    if (current == null || !current.categoryOptions.contains(category)) return;
    _update((s) => s.copyWith(category: category));
  }

  void setNote(String note) => _update((s) => s.copyWith(note: note));

  /// Registra el gasto o guarda los cambios.
  Future<ConfirmMovementResult> save() async {
    final current = state.value;
    if (current == null || !current.canSave) return dataSaveErrorMessage;
    final amount = current.amount!;
    final category = current.category!;
    final note = current.note.trim();

    return _run(current, () async {
      switch (mode) {
        case CreateMovementMode(:final method):
          await ref
              .read(registerMovementProvider)
              .call(
                amount: amount,
                categoryId: category.categoryId,
                origin: method == MovementEntryMethod.photo
                    ? MovementOrigin.photo
                    : MovementOrigin.manual,
                // Vacía en el registro manual: se usa el nombre de la categoría.
                description: method == MovementEntryMethod.photo
                    ? demoReceiptMerchantName
                    : '',
                note: note.isEmpty ? null : note,
              );
        case EditMovementMode(:final movementId):
          await ref
              .read(updateMovementProvider)
              .call(
                id: movementId,
                amount: amount,
                categoryId: category.categoryId,
                note: () => note.isEmpty ? null : note,
              );
      }
    });
  }

  /// Elimina el movimiento que se edita (borrado lógico).
  Future<ConfirmMovementResult> delete() async {
    final current = state.value;
    final mode = this.mode;
    if (current == null || mode is! EditMovementMode || current.isSaving) {
      return dataSaveErrorMessage;
    }
    return _run(
      current,
      () => ref.read(deleteMovementProvider).call(mode.movementId),
    );
  }

  /// Ejecuta [action] marcando el estado como guardando. No registra el error
  /// en logs: puede incluir datos del usuario (docs/08 §8.8.5).
  Future<ConfirmMovementResult> _run(
    ConfirmMovementState current,
    Future<void> Function() action,
  ) async {
    state = AsyncData(current.copyWith(isSaving: true));
    try {
      await action();
      return null;
    } catch (error) {
      return userMessageFor(error);
    } finally {
      // La pantalla puede haberse cerrado mientras tanto.
      if (ref.mounted) {
        final latest = state.value;
        if (latest != null) state = AsyncData(latest.copyWith(isSaving: false));
      }
    }
  }
}
