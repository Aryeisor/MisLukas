import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/repositories/account_repository.dart';

/// Archivos de una carpeta de Storage. Separado de Supabase para probar la
/// paginación del borrado sin red.
abstract interface class StoredFiles {
  /// Hasta [limit] nombres de archivo dentro de [folder].
  Future<List<String>> list(String folder, {required int limit});

  /// Borra [paths] (carpeta/archivo).
  Future<void> remove(List<String> paths);
}

/// Borra todos los archivos de [folder], de a [pageSize] por vez: la API de
/// Storage lista como máximo 100. Cada página borrada deja de aparecer, por
/// eso siempre se pide la primera.
Future<void> deleteAllFiles(
  StoredFiles files,
  String folder, {
  int pageSize = 100,
}) async {
  List<String>? previous;
  while (true) {
    final names = await files.list(folder, limit: pageSize);
    if (names.isEmpty) return;
    // Si la página no cambió, el borrado no tuvo efecto (por ejemplo, sin
    // permiso): se detiene en lugar de repetir para siempre.
    if (previous != null && _sameNames(previous, names)) {
      throw const AccountDeletionException(AccountDeletionFailure.unknown);
    }
    previous = names;
    await files.remove([for (final name in names) '$folder/$name']);
  }
}

bool _sameNames(List<String> a, List<String> b) =>
    a.length == b.length && a.toSet().containsAll(b);

/// Archivos del bucket privado `recibos` (supabase/migrations/007 y 009).
class SupabaseStoredFiles implements StoredFiles {
  SupabaseStoredFiles(this._storage);

  final SupabaseStorageClient _storage;

  static const String bucket = 'recibos';

  @override
  Future<List<String>> list(String folder, {required int limit}) async {
    final objects = await _storage
        .from(bucket)
        .list(
          path: folder,
          searchOptions: SearchOptions(limit: limit),
        );
    return [for (final object in objects) object.name];
  }

  @override
  Future<void> remove(List<String> paths) =>
      _storage.from(bucket).remove(paths);
}

/// [AccountRepository] con Supabase: borra los archivos con la API de Storage
/// (SQL no puede borrarlos) y luego llama a `eliminar_mi_cuenta()`
/// (supabase/migrations/009), que borra el usuario y, en cascada, sus datos.
class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(this._client, {StoredFiles? files})
    : _files = files ?? SupabaseStoredFiles(_client.storage);

  final SupabaseClient _client;
  final StoredFiles _files;

  static const Duration _timeout = Duration(seconds: 30);

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AccountDeletionException(
        AccountDeletionFailure.reauthenticationRequired,
      );
    }
    return id;
  }

  @override
  Future<void> deleteStoredFiles() =>
      _guard(() => deleteAllFiles(_files, _userId));

  @override
  Future<void> deleteAccount() =>
      _guard(() => _client.rpc<dynamic>('eliminar_mi_cuenta'));

  /// El mensaje del servidor nunca llega al usuario.
  static Future<void> _guard(Future<void> Function() action) async {
    try {
      await action().timeout(_timeout);
    } on AccountDeletionException {
      rethrow;
    } on PostgrestException catch (error) {
      if (error.hint == 'reautenticacion' || error.code == '401') {
        throw const AccountDeletionException(
          AccountDeletionFailure.reauthenticationRequired,
        );
      }
      final status = int.tryParse(error.code ?? '');
      throw AccountDeletionException(
        status != null && status >= 500
            ? AccountDeletionFailure.network
            : AccountDeletionFailure.unknown,
      );
    } on StorageException catch (error) {
      final status = int.tryParse(error.statusCode ?? '');
      throw AccountDeletionException(
        status == null || status >= 500
            ? AccountDeletionFailure.network
            : AccountDeletionFailure.unknown,
      );
    } on SocketException {
      throw const AccountDeletionException(AccountDeletionFailure.network);
    } on TimeoutException {
      throw const AccountDeletionException(AccountDeletionFailure.network);
    } catch (_) {
      throw const AccountDeletionException(AccountDeletionFailure.network);
    }
  }
}
