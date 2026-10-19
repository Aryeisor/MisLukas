import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/database/local_data_wiper.dart';
import 'package:mislukas/core/security/app_lock_clock.dart';
import 'package:mislukas/core/security/app_lock_store.dart';
import 'package:mislukas/core/security/device_authenticator.dart';
import 'package:mislukas/core/security/device_session_store.dart';
import 'package:mislukas/core/sync/network_monitor.dart';
import 'package:mislukas/core/sync/sync_providers.dart';
import 'package:mislukas/features/budgets/data/budgets_providers.dart';

import 'fake_app_lock.dart';
import 'fake_auth_repository.dart';
import 'fake_device_signals.dart';
import 'fake_sync_server.dart';

/// [DeviceSessionStore] en memoria.
class MemoryDeviceSessionStore implements DeviceSessionStore {
  MemoryDeviceSessionStore({
    this.owner,
    this.recoveryInProgress = false,
    this.parkedUser,
  });

  String? owner;
  bool recoveryInProgress;

  /// Sesión en espera del bloqueo del celular.
  String? parkedUser;

  /// Hace fallar la siguiente escritura de la sesión en espera.
  bool failNextParkedWrite = false;

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

  @override
  Future<String?> readParkedUser() async => parkedUser;

  @override
  Future<void> writeParkedUser(String userId) async {
    if (failNextParkedWrite) {
      failNextParkedWrite = false;
      throw StateError('Fallo simulado del almacenamiento seguro');
    }
    parkedUser = userId;
  }

  @override
  Future<void> clearParkedUser() async => parkedUser = null;
}

/// Borrado de los datos locales sobre la base en memoria: deja solo las
/// categorías predeterminadas, como una base nueva, y borra el dueño. Como el
/// real, también borra la sesión en espera y la preferencia de ingreso con el
/// bloqueo del celular.
class FakeLocalDataWiper implements LocalDataWiper {
  FakeLocalDataWiper(this._db, this._store, [this._appLockStore]);

  final AppDatabase? _db;
  final DeviceSessionStore _store;
  final AppLockStore? _appLockStore;

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
        await db.delete(db.sentBudgetAlerts).go();
        // La marca de la bienvenida vive en la base: se va con el archivo.
        await db.delete(db.localSettings).go();
      });
    }
    await _store.clearOwner();
    await _store.clearParkedUser();
    await _appLockStore?.clear();
  }
}

/// Lo que rodea la sesión en las pruebas de la app: almacenamiento seguro en
/// memoria, servidor de Supabase falso, borrado de datos falso, red,
/// notificaciones y su permiso falsos, bloqueo del celular falso y sin
/// sincronización automática (se sincroniza a mano).
///
/// Por defecto el bloqueo de la app está apagado y el celular no tiene
/// bloqueo de pantalla: no se ofrece activarlo al iniciar sesión. Las pruebas
/// del bloqueo pasan un [FakeDeviceAuthenticator] con bloqueo.
class TestSession {
  TestSession({
    MemoryDeviceSessionStore? store,
    FakeSyncServer? server,
    this.initialOwner,
    this.userId,
    this.autoSync = false,
    FakeNetworkMonitor? network,
    FakeBudgetAlertNotifier? notifier,
    FakeNotificationPermission? notificationPermission,
    MemoryAppLockStore? appLockStore,
    FakeDeviceAuthenticator? authenticator,
    FakeAppLockClock? lockClock,
  }) : appLockStore = appLockStore ?? MemoryAppLockStore(),
       authenticator = authenticator ?? FakeDeviceAuthenticator(hasLock: false),
       lockClock = lockClock ?? FakeAppLockClock(),
       store = store ?? MemoryDeviceSessionStore(owner: initialOwner),
       server = server ?? FakeSyncServer(),
       network = network ?? FakeNetworkMonitor(),
       notifier = notifier ?? FakeBudgetAlertNotifier(),
       notificationPermission =
           notificationPermission ?? FakeNotificationPermission();

  final MemoryDeviceSessionStore store;
  final FakeSyncServer server;
  final FakeNetworkMonitor network;
  final FakeBudgetAlertNotifier notifier;
  final FakeNotificationPermission notificationPermission;

  /// Preferencia de bloqueo; su valor inicial es lo que main() lee al abrir.
  final MemoryAppLockStore appLockStore;
  final FakeDeviceAuthenticator authenticator;
  final FakeAppLockClock lockClock;

  /// Dueño de la base al abrir la app (lo que main() lee del almacenamiento).
  final String? initialOwner;

  /// Usuario de la fuente remota; por defecto la usuaria de pruebas.
  final String? userId;
  final bool autoSync;

  FakeLocalDataWiper? _wiper;

  /// El borrado creado por [overrides].
  FakeLocalDataWiper get wiper => _wiper!;

  List<Override> overrides(AppDatabase? database) {
    final wiper = _wiper = FakeLocalDataWiper(database, store, appLockStore);
    return [
      deviceSessionStoreProvider.overrideWithValue(store),
      initialLocalOwnerProvider.overrideWithValue(initialOwner),
      initialParkedUserProvider.overrideWithValue(store.parkedUser),
      syncRemoteSourceProvider.overrideWithValue(
        server.sourceFor(userId ?? testUser.id),
      ),
      syncAutoTriggersProvider.overrideWithValue(autoSync),
      localDataWiperProvider.overrideWithValue(wiper),
      networkMonitorProvider.overrideWithValue(network),
      budgetAlertNotifierProvider.overrideWithValue(notifier),
      notificationPermissionProvider.overrideWithValue(notificationPermission),
      appLockStoreProvider.overrideWithValue(appLockStore),
      initialAppLockEnabledProvider.overrideWithValue(appLockStore.enabled),
      deviceAuthenticatorProvider.overrideWithValue(authenticator),
      appLockClockProvider.overrideWithValue(lockClock),
    ];
  }
}
