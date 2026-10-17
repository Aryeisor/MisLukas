// Fuente remota de la sincronización (docs/06 §6.6.2). El servicio de
// sincronización solo conoce esta interfaz: en la app la implementa Supabase
// y en las pruebas un servidor en memoria.

/// Posición en el orden de descarga (sincronizado_en, id). Sin [id], la
/// página empieza en [syncedAt] incluido.
class SyncCursor {
  const SyncCursor(this.syncedAt, [this.id]);

  final DateTime syncedAt;
  final String? id;
}

abstract interface class SyncRemoteSource {
  /// Comprueba que haya sesión y la renueva si el token venció. Lanza
  /// [SyncAuthException] o [SyncNetworkException].
  Future<void> ensureSession();

  /// Inserta o actualiza [rows] por `id` (upsert). Todas las filas de una
  /// llamada tienen las mismas columnas.
  Future<void> upsert(String table, List<Map<String, dynamic>> rows);

  /// Hasta [limit] filas de [table] posteriores a [after] en el orden
  /// (sincronizado_en, id); todas si [after] es null. RLS limita las filas a
  /// las del usuario (y, en categorías, a las predeterminadas).
  Future<List<Map<String, dynamic>>> fetchAfter(
    String table, {
    required SyncCursor? after,
    required int limit,
  });
}

/// Error de la fuente remota. No incluye datos del usuario.
sealed class SyncException implements Exception {
  const SyncException();
}

/// Sin conexión, tiempo agotado, 5xx o demasiadas solicitudes: se reintenta
/// más tarde y no se marca ningún registro.
class SyncNetworkException extends SyncException {
  const SyncNetworkException();

  @override
  String toString() => 'SyncNetworkException';
}

/// No hay sesión o el servidor la rechazó.
class SyncAuthException extends SyncException {
  const SyncAuthException();

  @override
  String toString() => 'SyncAuthException';
}

/// El servidor rechazó los datos (validación, RLS, llave foránea, único).
/// [code] es el código de PostgreSQL o de PostgREST, sin el mensaje.
class SyncRecordException extends SyncException {
  const SyncRecordException(this.code);

  /// Violación de una restricción única (23505).
  static const String uniqueViolation = '23505';

  final String code;

  @override
  String toString() => 'SyncRecordException($code)';
}
