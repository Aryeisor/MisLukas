import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_data.dart';
import '../../../core/theme/category_style.dart';
import '../../../core/utils/validators.dart';
import 'movement_entry_method.dart';

/// Máximo de caracteres de la nota.
const int movementNoteMaxLength = 200;

/// Categorías que se pueden elegir para un gasto en Confirma los datos (§5.2).
const List<CategoryKind> expenseCategoryOptions = [
  CategoryKind.mercado,
  CategoryKind.transporte,
  CategoryKind.ocio,
  CategoryKind.servicios,
  CategoryKind.restaurantes,
];

/// Estado inmutable de Confirma los datos.
class ConfirmMovementState {
  const ConfirmMovementState({
    required this.method,
    this.amount,
    this.category,
    this.note = '',
  });

  final MovementEntryMethod method;
  final int? amount;
  final CategoryKind? category;
  final String note;

  /// Guardar requiere un valor mayor que cero y una categoría.
  bool get canSave => isValidAmount(amount) && category != null;

  ConfirmMovementState copyWith({
    int? Function()? amount,
    CategoryKind? category,
    String? note,
  }) {
    return ConfirmMovementState(
      method: method,
      amount: amount != null ? amount() : this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
    );
  }
}

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

final confirmMovementViewModelProvider = NotifierProvider.autoDispose
    .family<ConfirmMovementViewModel, ConfirmMovementState, MovementEntryMethod>(
      ConfirmMovementViewModel.new,
    );

class ConfirmMovementViewModel extends Notifier<ConfirmMovementState> {
  ConfirmMovementViewModel(this.method);

  final MovementEntryMethod method;

  @override
  ConfirmMovementState build() {
    return switch (method) {
      MovementEntryMethod.photo => ConfirmMovementState(
        method: method,
        amount: demoReceiptTotal,
        category: demoReceiptCategory,
      ),
      MovementEntryMethod.manual => ConfirmMovementState(method: method),
    };
  }

  void setAmount(int? amount) => state = state.copyWith(amount: () => amount);

  void setCategory(CategoryKind category) =>
      state = state.copyWith(category: category);

  void setNote(String note) => state = state.copyWith(note: note);

  /// Guarda el gasto. Devuelve false si los datos no son válidos.
  bool save() {
    final amount = state.amount;
    final category = state.category;
    if (!state.canSave || amount == null || category == null) return false;

    final note = state.note.trim();
    final title = note.isNotEmpty
        ? note
        : switch (method) {
            MovementEntryMethod.photo => demoReceiptMerchantName,
            MovementEntryMethod.manual => category.label,
          };

    ref
        .read(demoMovementsProvider.notifier)
        .addExpense(title: title, category: category, amount: amount);
    return true;
  }
}
