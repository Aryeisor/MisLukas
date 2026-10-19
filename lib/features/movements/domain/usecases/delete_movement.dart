import '../../../../core/errors/domain_exception.dart';
import '../../../../core/utils/clock.dart';
import '../repositories/movement_repository.dart';
import '../repositories/receipt_image_store.dart';

/// Elimina un movimiento con borrado lógico (RF-23, docs/06 §6.4.1). Si tenía
/// recibo, también borra su imagen del dispositivo.
class DeleteMovement {
  const DeleteMovement({
    required this._movements,
    required this._clock,
    this._images,
  });

  final MovementRepository _movements;
  final Clock _clock;
  final ReceiptImageStore? _images;

  /// Lanza [DomainException] si el movimiento no existe o ya fue eliminado.
  Future<void> call(String id) async {
    final current = await _movements.findById(id);
    if (current == null || current.isDeleted) {
      throw const DomainException(DomainError.movementNotFound);
    }
    final receipt = await _movements.findReceipt(id);
    await _movements.softDelete(id, at: _clock.now());
    // Si no se puede borrar ahora, la limpieza del próximo arranque lo hace.
    await _images?.delete(receipt?.localPath);
  }
}
