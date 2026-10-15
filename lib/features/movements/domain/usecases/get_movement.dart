import '../../../../core/errors/domain_exception.dart';
import '../entities/movement.dart';
import '../repositories/movement_repository.dart';

/// Un movimiento por su identificador, para editarlo (RF-23).
class GetMovement {
  const GetMovement({required this._movements});

  final MovementRepository _movements;

  /// Lanza [DomainException] si el movimiento no existe o fue eliminado.
  Future<Movement> call(String id) async {
    final movement = await _movements.findById(id);
    if (movement == null || movement.isDeleted) {
      throw const DomainException(DomainError.movementNotFound);
    }
    return movement;
  }
}
