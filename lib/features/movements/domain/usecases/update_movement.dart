import '../../../../core/errors/domain_exception.dart';
import '../../../../core/sync/sync_status.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/validators.dart';
import '../../../budgets/domain/repositories/category_repository.dart';
import '../entities/movement.dart';
import '../movement_text.dart';
import '../repositories/movement_repository.dart';

/// Edita un movimiento existente (RF-23). Los campos en null no cambian; la
/// nota se borra con `note: () => null`.
class UpdateMovement {
  const UpdateMovement({
    required this._movements,
    required this._categories,
    required this._clock,
  });

  final MovementRepository _movements;
  final CategoryRepository _categories;
  final Clock _clock;

  /// Lanza [DomainException] si el movimiento no existe o los datos no son
  /// válidos.
  Future<Movement> call({
    required String id,
    int? amount,
    String? categoryId,
    DateTime? date,
    String? description,
    String? Function()? note,
  }) async {
    final current = await _movements.findById(id);
    if (current == null || current.isDeleted) {
      throw const DomainException(DomainError.movementNotFound);
    }
    if (amount != null && !isValidAmount(amount)) {
      throw const DomainException(DomainError.invalidAmount);
    }
    final now = _clock.now();
    if (date != null && dateOnly(date).isAfter(dateOnly(now))) {
      throw const DomainException(DomainError.futureDate);
    }

    var type = current.type;
    if (categoryId != null && categoryId != current.categoryId) {
      final category = await _categories.findById(categoryId);
      if (category == null) {
        throw const DomainException(DomainError.categoryNotFound);
      }
      type = category.type;
    }

    final cleanDescription = description == null
        ? null
        : sanitizeMovementText(description);
    String? cleanNote() {
      final value = note!();
      if (value == null) return null;
      final clean = sanitizeMovementText(value);
      return clean.isEmpty ? null : clean;
    }

    final newNote = note == null ? current.note : cleanNote();
    if ((cleanDescription?.length ?? 0) > movementTextMaxLength ||
        (newNote?.length ?? 0) > movementTextMaxLength) {
      throw const DomainException(DomainError.textTooLong);
    }

    final updated = current.copyWith(
      type: type,
      amount: amount,
      date: date == null ? null : dateOnly(date),
      categoryId: categoryId,
      // Una descripción vacía conserva la anterior.
      description: (cleanDescription?.isEmpty ?? true)
          ? null
          : cleanDescription,
      note: () => newNote,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );
    await _movements.update(updated);
    return updated;
  }
}
