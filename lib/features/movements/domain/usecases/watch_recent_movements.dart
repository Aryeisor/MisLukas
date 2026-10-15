import '../entities/movement.dart';
import '../repositories/movement_repository.dart';

/// Cantidad de movimientos en "Últimos movimientos" de Inicio.
const int recentMovementsLimit = 5;

/// Últimos movimientos, del más reciente al más antiguo (RF-21).
class WatchRecentMovements {
  const WatchRecentMovements({required this._movements});

  final MovementRepository _movements;

  Stream<List<Movement>> call({int limit = recentMovementsLimit}) =>
      _movements.watchRecent(limit: limit);
}
