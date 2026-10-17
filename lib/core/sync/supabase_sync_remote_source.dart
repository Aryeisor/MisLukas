import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'remote_json.dart';
import 'sync_remote_source.dart';

/// [SyncRemoteSource] con Supabase (PostgREST). Las consultas se construyen
/// con los métodos del cliente: los valores viajan como parámetros
/// (docs/08 §8.6). RLS limita cada consulta a las filas del usuario.
class SupabaseSyncRemoteSource implements SyncRemoteSource {
  SupabaseSyncRemoteSource(this._client);

  final SupabaseClient _client;

  /// Tiempo máximo de cada solicitud.
  static const Duration requestTimeout = Duration(seconds: 20);

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  Future<void> ensureSession() async {
    final session = _client.auth.currentSession;
    if (session == null) throw const SyncAuthException();
    if (!session.isExpired) return;
    try {
      await _client.auth.refreshSession().timeout(requestTimeout);
    } on AuthRetryableFetchException {
      throw const SyncNetworkException();
    } on AuthException {
      throw const SyncAuthException();
    } catch (_) {
      throw const SyncNetworkException();
    }
  }

  @override
  Future<void> upsert(String table, List<Map<String, dynamic>> rows) {
    return _guard(() => _client.from(table).upsert(rows, onConflict: 'id'));
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAfter(
    String table, {
    required SyncCursor? after,
    required int limit,
  }) {
    return _guard(() {
      PostgrestFilterBuilder<PostgrestList> query = _client
          .from(table)
          .select();
      if (after != null) {
        final timestamp = timestampToRemote(after.syncedAt);
        final id = after.id;
        if (id == null) {
          query = query.gte('sincronizado_en', timestamp);
        } else {
          // Paginación por llave: sincronizado_en > ts, o igual con id mayor.
          // Muchas filas comparten sincronizado_en (las de un mismo upsert),
          // por eso hace falta el id. El ts sale de un DateTime y el id se
          // valida: el filtro solo contiene valores conocidos, entre comillas,
          // y PostgREST los pasa como parámetros.
          if (!_uuidPattern.hasMatch(id)) {
            throw const SyncRecordException('id_invalido');
          }
          query = query.or(
            'sincronizado_en.gt."$timestamp",'
            'and(sincronizado_en.eq."$timestamp",id.gt.$id)',
          );
        }
      }
      return query
          .order('sincronizado_en', ascending: true)
          .order('id', ascending: true)
          .limit(limit);
    });
  }

  /// Traduce los errores del cliente a [SyncException]. El mensaje del
  /// servidor nunca se conserva: puede incluir valores de la fila.
  static Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request().timeout(requestTimeout);
    } on SyncException {
      rethrow;
    } on PostgrestException catch (error) {
      throw mapPostgrestCode(error.code);
    } on SocketException {
      throw const SyncNetworkException();
    } on TimeoutException {
      throw const SyncNetworkException();
    } on HandshakeException {
      throw const SyncNetworkException();
    } on FormatException {
      // Respuesta que no es JSON (por ejemplo, un proxy).
      throw const SyncNetworkException();
    } catch (_) {
      // ClientException de http y otros fallos de transporte.
      throw const SyncNetworkException();
    }
  }
}

/// Clasifica el código de un error de PostgREST: [code] es el SQLSTATE de
/// PostgreSQL, un código PGRST o el estado HTTP si la respuesta no era JSON.
SyncException mapPostgrestCode(String? code) {
  if (code == null || code.isEmpty) return const SyncNetworkException();
  // Sesión: JWT inválido o vencido.
  if (code == '401' || code.startsWith('PGRST30')) {
    return const SyncAuthException();
  }
  // Conexión de PostgREST con la base, tiempo agotado o servidor caído.
  if (code.startsWith('PGRST00') ||
      code == '408' ||
      code == '429' ||
      code == '57014' ||
      (code.length == 3 && code.startsWith('5'))) {
    return const SyncNetworkException();
  }
  return SyncRecordException(code);
}
