import '../entities/movement.dart';
import '../entities/receipt.dart';

/// Acceso a los movimientos. Las consultas excluyen los eliminados.
///
/// Toda escritura deja el registro como pendiente de sincronizar y agrega su
/// entrada a la cola de sincronización en la misma transacción.
abstract interface class MovementRepository {
  /// Guarda un movimiento nuevo y, si se registró por foto, su recibo.
  Future<void> add(Movement movement, {Receipt? receipt});

  /// Reemplaza los datos de un movimiento existente.
  Future<void> update(Movement movement);

  /// Marca el movimiento (y su recibo) como eliminado en [at].
  Future<void> softDelete(String id, {required DateTime at});

  Future<Movement?> findById(String id);

  /// Los [limit] movimientos más recientes, del más nuevo al más antiguo.
  Stream<List<Movement>> watchRecent({required int limit});

  /// Movimientos con fecha en [from, to), del más reciente al más antiguo.
  Stream<List<Movement>> watchBetween(DateTime from, DateTime to);

  /// Igual que [watchBetween], una sola vez.
  Future<List<Movement>> getBetween(DateTime from, DateTime to);
}
