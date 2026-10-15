import '../../../../core/errors/domain_exception.dart';
import '../../../../core/utils/clock.dart';
import '../repositories/movement_repository.dart';

/// Elimina un movimiento con borrado lógico (RF-23, docs/06 §6.4.1).
class DeleteMovement {
  const DeleteMovement({required this._movements, required this._clock});

  final MovementRepository _movements;
  final Clock _clock;

  /// Lanza [DomainException] si el movimiento no existe o ya fue eliminado.
  Future<void> call(String id) async {
    final current = await _movements.findById(id);
    if (current == null || current.isDeleted) {
      throw const DomainException(DomainError.movementNotFound);
    }
    await _movements.softDelete(id, at: _clock.now());
  }
}
