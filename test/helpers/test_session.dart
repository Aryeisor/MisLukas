import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/database/local_data_wiper.dart';
import 'package:mislukas/core/security/device_session_store.dart';
import 'package:mislukas/core/sync/sync_providers.dart';

import 'fake_auth_repository.dart';
import 'fake_sync_server.dart';

/// [DeviceSessionStore] en memoria.
class MemoryDeviceSessionStore implements DeviceSessionStore {
  MemoryDeviceSessionStore({this.owner, this.recoveryInProgress = false});

  String? owner;
  bool recoveryInProgress;

  @override
  Future<String?> readOwner() async => owner;

  @override
  Future<void> writeOwner(String userId) async => owner = userId;

  @override
  Future<void> clearOwner() async => owner = null;

  @override
  Future<bool> readRecoveryInProgress() async => recoveryInProgress;

  @override
  Future<void> writeRecoveryInProgress(bool inProgress) async =>
      recoveryInProgress = inProgress;
}

/// Borrado de los datos locales sobre la base en memoria: deja solo las
/// categorías predeterminadas, como una base nueva, y borra el dueño.
class FakeLocalDataWiper implements LocalDataWiper {
  FakeLocalDataWiper(this._db, this._store);

  final AppDatabase? _db;
  final DeviceSessionStore _store;

  /// Veces que se borró.
  int wipes = 0;

  /// Hace fallar el siguiente borrado.
  bool failNext = false;

  /// El siguiente borrado no termina nunca (por ejemplo, la base no cierra).
  bool hangNext = false;

  @override
  Future<void> wipe() async {
    if (hangNext) {
      hangNext = false;
      return Completer<void>().future;
    }
    if (failNext) {
      failNext = false;
      throw StateError('Fallo simulado al borrar');
    }
    wipes++;
    final db = _db;
    if (db != null) {
      await db.transaction(() async {
        await db.delete(db.receipts).go();
        await db.delete(db.movements).go();
        await db.delete(db.budgets).go();
        await db.delete(db.syncQueue).go();
        await db.delete(db.syncMetadata).go();
        // La marca de la bienvenida vive en la base: se va con el archivo.
        await db.delete(db.localSettings).go();
      });
    }
    await _store.clearOwner();
  }
}

/// Lo que rodea la sesión en las pruebas de la app: almacenamiento seguro en
/// memoria, servidor de Supabase falso, borrado de datos falso y sin
/// sincronización automática (se sincroniza a mano).
class TestSession {
  TestSession({
    MemoryDeviceSessionStore? store,
    FakeSyncServer? server,
    this.initialOwner,
    this.userId,
    this.autoSync = false,
  }) : store = store ?? MemoryDeviceSessionStore(owner: initialOwner),
       server = server ?? FakeSyncServer();

  final MemoryDeviceSessionStore store;
  final FakeSyncServer server;

  /// Dueño de la base al abrir la app (lo que main() lee del almacenamiento).
  final String? initialOwner;

  /// Usuario de la fuente remota; por defecto la usuaria de pruebas.
  final String? userId;
  final bool autoSync;

  FakeLocalDataWiper? _wiper;

  /// El borrado creado por [overrides].
  FakeLocalDataWiper get wiper => _wiper!;

  List<Override> overrides(AppDatabase? database) {
    final wiper = _wiper = FakeLocalDataWiper(database, store);
    return [
      deviceSessionStoreProvider.overrideWithValue(store),
      initialLocalOwnerProvider.overrideWithValue(initialOwner),
      syncRemoteSourceProvider.overrideWithValue(
        server.sourceFor(userId ?? testUser.id),
      ),
      syncAutoTriggersProvider.overrideWithValue(autoSync),
      localDataWiperProvider.overrideWithValue(wiper),
    ];
  }
}
