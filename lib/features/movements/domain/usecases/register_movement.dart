import '../../../../core/errors/domain_exception.dart';
import '../../../../core/sync/sync_status.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../core/utils/validators.dart';
import '../../../budgets/domain/repositories/category_repository.dart';
import '../entities/movement.dart';
import '../entities/receipt.dart';
import '../movement_text.dart';
import '../repositories/movement_repository.dart';

/// Datos del recibo de un gasto registrado por foto, antes de guardarse.
class ReceiptDraft {
  const ReceiptDraft({
    required this.localPath,
    this.detectedTotal,
    this.detectedMerchant,
  });

  final String localPath;
  final int? detectedTotal;
  final String? detectedMerchant;
}

/// Registra un gasto o un ingreso (docs/06 §6.3.1).
///
/// Valida que el monto sea mayor que cero (RF-20), que la categoría exista y
/// que la fecha no sea posterior a hoy.
/// El tipo del movimiento es el de su categoría. Si la descripción queda vacía,
/// se usa el nombre de la categoría.
class RegisterMovement {
  const RegisterMovement({
    required this._movements,
    required this._categories,
    required this._clock,
    required this._ids,
  });

  final MovementRepository _movements;
  final CategoryRepository _categories;
  final Clock _clock;
  final IdGenerator _ids;

  /// Lanza [DomainException] si los datos no son válidos.
  Future<Movement> call({
    required int? amount,
    required String categoryId,
    required MovementOrigin origin,
    String description = '',
    String? note,
    DateTime? date,
    ReceiptDraft? receipt,
  }) async {
    if (!isValidAmount(amount)) {
      throw const DomainException(DomainError.invalidAmount);
    }
    final category = await _categories.findById(categoryId);
    if (category == null) {
      throw const DomainException(DomainError.categoryNotFound);
    }

    final cleanDescription = sanitizeMovementText(description);
    final cleanNote = note == null ? null : sanitizeMovementText(note);
    if (cleanDescription.length > movementTextMaxLength ||
        (cleanNote?.length ?? 0) > movementTextMaxLength) {
      throw const DomainException(DomainError.textTooLong);
    }

    final now = _clock.now();
    final movementDate = dateOnly(date ?? now);
    if (movementDate.isAfter(dateOnly(now))) {
      throw const DomainException(DomainError.futureDate);
    }

    final movement = Movement(
      id: _ids.newId(),
      type: category.type,
      amount: amount!,
      date: movementDate,
      categoryId: category.id,
      description: cleanDescription.isEmpty ? category.name : cleanDescription,
      note: (cleanNote?.isEmpty ?? true) ? null : cleanNote,
      origin: origin,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );

    await _movements.add(
      movement,
      receipt: receipt == null
          ? null
          : Receipt(
              id: _ids.newId(),
              movementId: movement.id,
              localPath: receipt.localPath,
              detectedTotal: isValidAmount(receipt.detectedTotal)
                  ? receipt.detectedTotal
                  : null,
              detectedMerchant: sanitizeDetectedText(receipt.detectedMerchant),
            ),
    );
    return movement;
  }
}
