import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../notifications/local_notifications.dart';
import '../security/app_lock_store.dart';
import '../security/database_key_store.dart';
import '../security/device_session_store.dart';
import '../security/receipt_key_store.dart';
import 'database_connection.dart';
import 'database_providers.dart';

/// Borra todos los datos locales del usuario (docs/08 §8.8.4): al cerrar
/// sesión, al eliminar la cuenta o cuando entra otro usuario. Los tokens los
/// borra el cierre de sesión de Supabase.
abstract interface class LocalDataWiper {
  Future<void> wipe();
}

/// Borra las claves de cifrado (de la base y de las imágenes de recibos) y el
/// dueño, y luego cierra la base y borra su archivo y las imágenes de
/// recibos. La próxima base y las próximas imágenes usan claves nuevas.
///
/// Las claves y el dueño van primero porque deciden de quién son los datos:
/// sin las claves, lo que quede de la base o de las imágenes no se puede leer (se descarta al abrir la
/// base nueva, [deleteStaleDatabase]) y, sin dueño, la próxima cuenta entra sin
/// aviso. Solo falla si no se pueden borrar esos dos. Cerrar la base y borrar
/// archivos no bloquea: tienen tiempo máximo y sus errores se ignoran.
///
/// También quita las notificaciones de alertas mostradas. El registro de
/// alertas enviadas y los ajustes del dispositivo viven en la base y se van
/// con ella.
///
/// También borra la sesión en espera y la preferencia "Ingresar con huella,
/// rostro o PIN" ([AppLockStore]): acompañan a los datos de la cuenta y quien
/// entre después no las hereda (docs/08 §8.8.4).
class FileLocalDataWiper implements LocalDataWiper {
  FileLocalDataWiper({
    required this._closeDatabase,
    required this._directory,
    required this._keyStore,
    required this._receiptKeyStore,
    required this._sessionStore,
    required this._appLockStore,
    required this._onWiped,
    this._cancelNotifications,
  });

  final Future<void> Function() _closeDatabase;
  final Future<Directory> Function() _directory;
  final DatabaseKeyStore _keyStore;
  final ReceiptKeyStore _receiptKeyStore;
  final DeviceSessionStore _sessionStore;
  final AppLockStore _appLockStore;

  /// Libera la base cerrada para que el próximo uso abra una nueva.
  final void Function() _onWiped;

  /// Quita las notificaciones mostradas; null si no hay (pruebas).
  final Future<void> Function()? _cancelNotifications;

  /// Tiempo máximo para cerrar la base.
  static const Duration closeTimeout = Duration(seconds: 5);

  /// Archivos de la base: el principal y los temporales de SQLite.
  static const List<String> databaseFiles = localDatabaseFiles;

  @override
  Future<void> wipe() async {
    await _keyStore.deleteKey();
    await _receiptKeyStore.deleteKey();
    await _sessionStore.clearOwner();

    try {
      await _sessionStore.clearParkedUser();
      await _appLockStore.clear();
    } catch (_) {
      // La marca obsoleta se descarta al iniciar sesión otra cuenta; la
      // preferencia sin datos no impide seguir con el borrado.
    }
    try {
      await _cancelNotifications?.call().timeout(closeTimeout);
    } catch (_) {
      // Las notificaciones no tienen montos: se sigue con el borrado.
    }
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
    receiptKeyStore: ref.read(receiptKeyStoreProvider),
    sessionStore: ref.read(deviceSessionStoreProvider),
    appLockStore: ref.read(appLockStoreProvider),
    onWiped: () => ref.invalidate(appDatabaseProvider),
    cancelNotifications: ref.read(localNotificationsProvider).cancelAll,
  ),
);
