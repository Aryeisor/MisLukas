import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/theme/category_mapping.dart';
import '../../../core/theme/category_style.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/utils_providers.dart';
import '../../../core/utils/validators.dart';
import '../data/movements_providers.dart';
import '../domain/entities/movement.dart';
import '../domain/entities/receipt_suggestion.dart';
import '../domain/usecases/register_movement.dart';
import 'receipt/receipt_capture.dart';
import 'receipt/receipt_drafts.dart';

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

/// Para qué se abre el formulario: registrar un gasto o un ingreso nuevo, o
/// editar un movimiento existente.
sealed class ConfirmMovementMode {
  const ConfirmMovementMode();
}

/// Registrar un gasto nuevo a mano ("Registra tu gasto").
class CreateManualMovementMode extends ConfirmMovementMode {
  const CreateManualMovementMode();

  @override
  bool operator ==(Object other) => other is CreateManualMovementMode;

  @override
  int get hashCode => (CreateManualMovementMode).hashCode;
}

/// Registrar un gasto con la foto del recibo ya leída ("Confirma los datos").
class CreatePhotoMovementMode extends ConfirmMovementMode {
  const CreatePhotoMovementMode(this.capture);

  final ReceiptCapture capture;

  @override
  bool operator ==(Object other) =>
      other is CreatePhotoMovementMode && other.capture == capture;

  @override
  int get hashCode => Object.hash(CreatePhotoMovementMode, capture);
}

/// Registrar un ingreso nuevo (RF-50): categoría Ingreso, origen manual y sin
/// recibo. El formulario vive en Nuevo movimiento.
class CreateIncomeMode extends ConfirmMovementMode {
  const CreateIncomeMode();

  @override
  bool operator ==(Object other) => other is CreateIncomeMode;

  @override
  int get hashCode => (CreateIncomeMode).hashCode;
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

/// Estado inmutable de Confirma los datos, del formulario de ingreso y de
/// Editar movimiento.
class ConfirmMovementState {
  const ConfirmMovementState({
    required this.mode,
    this.amount,
    this.category,
    this.note = '',
    this.description = '',
    this.merchant = '',
    this.date,
    this.isIncome = false,
    this.isSaving = false,
  });

  final ConfirmMovementMode mode;
  final int? amount;
  final CategoryKind? category;
  final String note;

  /// Comercio del gasto por foto, precargado con lo que leyó el OCR. Se
  /// guarda como descripción; vacío, se usa el nombre de la categoría.
  final String merchant;

  /// Descripción del ingreso ("Salario"). Los gastos no la editan.
  final String description;

  /// Día del movimiento (RF-19). Por defecto, hoy.
  final DateTime? date;

  /// El movimiento que se edita es un ingreso. Al editar no cambia el tipo.
  final bool isIncome;

  /// Hay un guardado o una eliminación en curso.
  final bool isSaving;

  bool get isEditing => mode is EditMovementMode;

  /// Recibo del gasto por foto; null en los demás modos.
  ReceiptCapture? get receipt => switch (mode) {
    CreatePhotoMovementMode(:final capture) => capture,
    _ => null,
  };

  /// Resultado de la lectura del recibo; null si no es un gasto por foto.
  ReceiptScanStatus? get scanStatus => receipt?.suggestion.status;

  /// Categorías que se pueden elegir según el tipo del movimiento.
  List<CategoryKind> get categoryOptions =>
      isIncome ? incomeCategoryOptions : expenseCategoryOptions;

  /// Guardar requiere un valor mayor que cero y una categoría.
  bool get canSave => isValidAmount(amount) && category != null && !isSaving;

  ConfirmMovementState copyWith({
    int? Function()? amount,
    CategoryKind? category,
    String? note,
    String? description,
    String? merchant,
    DateTime? date,
    bool? isSaving,
  }) {
    return ConfirmMovementState(
      mode: mode,
      amount: amount != null ? amount() : this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
      description: description ?? this.description,
      merchant: merchant ?? this.merchant,
      date: date ?? this.date,
      isIncome: isIncome,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

/// Resultado de guardar o eliminar: null si salió bien; si no, el mensaje
/// para el usuario.
typedef ConfirmMovementResult = String?;

final confirmMovementViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<
      ConfirmMovementViewModel,
      ConfirmMovementState,
      ConfirmMovementMode
    >(ConfirmMovementViewModel.new);

class ConfirmMovementViewModel extends AsyncNotifier<ConfirmMovementState> {
  ConfirmMovementViewModel(this.mode);

  final ConfirmMovementMode mode;

  /// El gasto por foto ya se guardó: su imagen ya no es un borrador.
  bool _receiptSaved = false;

  // Al registrar, el estado está listo de inmediato; al editar, primero se
  // carga el movimiento.
  @override
  FutureOr<ConfirmMovementState> build() {
    return switch (mode) {
      CreatePhotoMovementMode(:final capture) => _photoState(capture),
      CreateManualMovementMode() => ConfirmMovementState(
        mode: mode,
        date: ref.read(clockProvider).today(),
      ),
      CreateIncomeMode() => ConfirmMovementState(
        mode: mode,
        category: CategoryKind.ingreso,
        date: ref.read(clockProvider).today(),
        isIncome: true,
      ),
      EditMovementMode(:final movementId) => _load(movementId),
    };
  }

  /// Precarga lo que leyó el OCR. Es una sugerencia: todo se puede corregir
  /// (RF-17). Si el usuario sale sin guardar, la imagen cifrada se borra.
  ConfirmMovementState _photoState(ReceiptCapture capture) {
    // Lo que se usa al cerrar se toma ahora: en onDispose no se usa ref.
    final images = ref.read(receiptImageStoreProvider);
    final drafts = ref.read(receiptDraftsInProgressProvider.notifier);
    // La captura ya lo registró; se asegura aquí, fuera de build (no se
    // modifica otro provider mientras este se construye).
    Future.microtask(() => drafts.add(capture.receiptId));
    ref.onDispose(() {
      if (_receiptSaved) return;
      unawaited(images.delete(capture.localPath));
      Future.microtask(() {
        try {
          drafts.remove(capture.receiptId);
        } catch (_) {
          // El contenedor ya se cerró.
        }
      });
    });

    final suggestion = capture.suggestion;
    final today = ref.read(clockProvider).today();
    final category = suggestion.category?.kind;
    return ConfirmMovementState(
      mode: mode,
      amount: suggestion.total,
      category: expenseCategoryOptions.contains(category) ? category : null,
      merchant: suggestion.merchant ?? '',
      // Nunca futura, aunque el reloj haya cambiado desde la lectura.
      date: suggestion.date.isAfter(today) ? today : suggestion.date,
    );
  }

  Future<ConfirmMovementState> _load(String movementId) async {
    final movement = await ref.read(getMovementProvider).call(movementId);
    return ConfirmMovementState(
      mode: mode,
      amount: movement.amount,
      category: categoryKindForId(movement.categoryId),
      note: movement.note ?? '',
      description: movement.description,
      date: movement.date,
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

  void setMerchant(String merchant) =>
      _update((s) => s.copyWith(merchant: merchant));

  void setDescription(String description) =>
      _update((s) => s.copyWith(description: description));

  /// Cambia el día del movimiento. Una fecha futura no se acepta (el
  /// calendario tampoco la ofrece).
  void setDate(DateTime date) {
    final day = dateOnly(date);
    if (day.isAfter(ref.read(clockProvider).today())) return;
    _update((s) => s.copyWith(date: day));
  }

  /// Registra el gasto o el ingreso, o guarda los cambios.
  Future<ConfirmMovementResult> save() async {
    final current = state.value;
    if (current == null || !current.canSave) return dataSaveErrorMessage;
    final amount = current.amount!;
    final category = current.category!;
    final note = current.note.trim();
    final description = current.description.trim();

    return _run(current, () async {
      switch (mode) {
        case CreateManualMovementMode():
          await ref
              .read(registerMovementProvider)
              .call(
                amount: amount,
                categoryId: category.categoryId,
                origin: MovementOrigin.manual,
                // Vacía: se usa el nombre de la categoría.
                description: '',
                note: note.isEmpty ? null : note,
                date: current.date,
              );
        case CreatePhotoMovementMode(:final capture):
          final suggestion = capture.suggestion;
          await ref
              .read(registerMovementProvider)
              .call(
                amount: amount,
                categoryId: category.categoryId,
                origin: MovementOrigin.photo,
                // Vacío: se usa el nombre de la categoría.
                description: current.merchant.trim(),
                note: note.isEmpty ? null : note,
                date: current.date,
                // Se guarda lo que leyó el OCR, aunque el usuario lo corrija.
                receipt: ReceiptDraft(
                  id: capture.receiptId,
                  localPath: capture.localPath,
                  detectedTotal: suggestion.total,
                  detectedMerchant: suggestion.merchant,
                ),
              );
          _receiptSaved = true;
          _removeDraft(capture.receiptId);
        case CreateIncomeMode():
          // Vacía: se usa el nombre de la categoría.
          await ref
              .read(registerIncomeProvider)
              .call(
                amount: amount,
                description: description,
                date: current.date,
              );
        case EditMovementMode(:final movementId) when current.isIncome:
          // El ingreso no cambia de categoría ni tiene nota en su formulario.
          // Una descripción vacía conserva la anterior.
          await ref
              .read(updateMovementProvider)
              .call(
                id: movementId,
                amount: amount,
                description: description,
                date: current.date,
              );
        case EditMovementMode(:final movementId):
          await ref
              .read(updateMovementProvider)
              .call(
                id: movementId,
                amount: amount,
                categoryId: category.categoryId,
                date: current.date,
                note: () => note.isEmpty ? null : note,
              );
      }
    });
  }

  void _removeDraft(String receiptId) {
    if (ref.mounted) {
      ref.read(receiptDraftsInProgressProvider.notifier).remove(receiptId);
    }
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
