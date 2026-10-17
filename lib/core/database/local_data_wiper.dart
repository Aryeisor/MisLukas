import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../security/database_key_store.dart';
import '../security/device_session_store.dart';
import 'database_connection.dart';
import 'database_providers.dart';

/// Borra todos los datos locales del usuario (docs/08 §8.8.4): al cerrar
/// sesión, al eliminar la cuenta o cuando entra otro usuario. Los tokens los
/// borra el cierre de sesión de Supabase.
abstract interface class LocalDataWiper {
  Future<void> wipe();
}

/// Borra la clave de cifrado y el dueño, y luego cierra la base y borra su
/// archivo y las imágenes de recibos. La próxima base se abre con una clave
/// nueva.
///
/// La clave y el dueño van primero porque deciden de quién son los datos: sin
/// la clave, lo que quede del archivo no se puede leer (se descarta al abrir la
/// base nueva, [deleteStaleDatabase]) y, sin dueño, la próxima cuenta entra sin
/// aviso. Solo falla si no se pueden borrar esos dos. Cerrar la base y borrar
/// archivos no bloquea: tienen tiempo máximo y sus errores se ignoran.
class FileLocalDataWiper implements LocalDataWiper {
  FileLocalDataWiper({
    required this._closeDatabase,
    required this._directory,
    required this._keyStore,
    required this._sessionStore,
    required this._onWiped,
  });

  final Future<void> Function() _closeDatabase;
  final Future<Directory> Function() _directory;
  final DatabaseKeyStore _keyStore;
  final DeviceSessionStore _sessionStore;

  /// Libera la base cerrada para que el próximo uso abra una nueva.
  final void Function() _onWiped;

  /// Tiempo máximo para cerrar la base.
  static const Duration closeTimeout = Duration(seconds: 5);

  /// Archivos de la base: el principal y los temporales de SQLite.
  static const List<String> databaseFiles = localDatabaseFiles;

  @override
  Future<void> wipe() async {
    await _keyStore.deleteKey();
    await _sessionStore.clearOwner();

    try {
      await _closeDatabase().timeout(closeTimeout);
    } catch (_) {
      // Sin la clave, la base abierta ya no sirve: se sigue con el borrado.
    }
    try {
      final directory = await _directory();
      await deleteDatabaseFiles(directory);
      final receipts = Directory(p.join(directory.path, receiptsDirectoryName));
      if (await receipts.exists()) await receipts.delete(recursive: true);
    } catch (_) {
      // Lo que quede no se puede leer sin la clave y se descarta al abrir la
      // base nueva.
    }
    try {
      _onWiped();
    } catch (_) {
      // La base nueva se abre igual en el próximo uso.
    }
  }
}

final localDataWiperProvider = Provider<LocalDataWiper>(
  (ref) => FileLocalDataWiper(
    closeDatabase: () => ref.read(appDatabaseProvider).close(),
    directory: getApplicationSupportDirectory,
    keyStore: ref.read(databaseKeyStoreProvider),
    sessionStore: ref.read(deviceSessionStoreProvider),
    onWiped: () => ref.invalidate(appDatabaseProvider),
  ),
);
