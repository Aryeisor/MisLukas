import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/account_session_controller.dart';
import '../utils/utils_providers.dart';
import 'local_sync_store.dart';
import 'network_monitor.dart';
import 'sync_providers.dart';
import 'sync_service.dart';

/// Estado de la sincronización para la interfaz (docs/05 §5.3, RF-47).
class SyncState {
  const SyncState({
    this.isSyncing = false,
    this.hasNetwork = true,
    this.lastAttemptOffline = false,
    this.pendingCount = 0,
    this.rejectedCount = 0,
    this.lastSyncedAt,
  });

  final bool isSyncing;

  /// El dispositivo está conectado a alguna red (connectivity_plus). Sin red
  /// el aviso se muestra de inmediato.
  final bool hasNetwork;

  /// El último intento falló por la red. Tener Wi-Fi no garantiza internet:
  /// el aviso solo se quita con una sincronización exitosa.
  final bool lastAttemptOffline;

  /// Aviso de "Sin conexión": sin red o con el último intento fallido.
  bool get isOffline => !hasNetwork || lastAttemptOffline;

  /// Registros con cambios sin enviar.
  final int pendingCount;

  /// Registros que el servidor rechazó y esperan su próximo intento.
  final int rejectedCount;

  /// Última sincronización completa en este dispositivo (hora local).
  final DateTime? lastSyncedAt;

  SyncState copyWith({
    bool? isSyncing,
    bool? hasNetwork,
    bool? lastAttemptOffline,
    int? pendingCount,
    int? rejectedCount,
    DateTime? lastSyncedAt,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      hasNetwork: hasNetwork ?? this.hasNetwork,
      lastAttemptOffline: lastAttemptOffline ?? this.lastAttemptOffline,
      pendingCount: pendingCount ?? this.pendingCount,
      rejectedCount: rejectedCount ?? this.rejectedCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

/// Decide cuándo sincronizar, solo con la sesión lista:
/// - al iniciar sesión y al abrir la app;
/// - después de cada escritura local, con una espera corta (debounce);
/// - al volver a primer plano ([onResume]);
/// - cada [periodicInterval] con la app abierta;
/// - sin conexión, con esperas crecientes hasta [maxOfflineRetry];
/// - al recuperar la red, [reconnectDebounce] después del último cambio, sin
///   esperar el backoff ni el intervalo.
///
/// "Sin conexión" combina la señal de connectivity_plus (sin red se muestra de
/// inmediato y no se reintenta) con el resultado del último intento (con red
/// pero sin internet, el intento falla y el aviso sigue).
class SyncController extends Notifier<SyncState> {
  /// Espera después de una escritura local.
  static const Duration writeDebounce = Duration(seconds: 2);

  /// Sincronización periódica con la app abierta (docs/06 §6.6.2).
  static const Duration periodicInterval = Duration(minutes: 5);

  /// Espera máxima entre intentos sin conexión: con ella los cambios llegan
  /// en menos de un minuto después de recuperar la conexión (RNF-10).
  static const Duration maxOfflineRetry = Duration(seconds: 60);

  /// Espera después de recuperar la red: si la red parpadea, se sincroniza una
  /// sola vez, cuando se estabiliza (docs/07 §7.8).
  static const Duration reconnectDebounce = Duration(seconds: 2);

  /// Espera antes del intento [attempt] sin conexión: 5, 10, 20, 40 y 60 s.
  static Duration offlineRetryDelay(int attempt) {
    final seconds = 5 * pow(2, (attempt - 1).clamp(0, 10)).toInt();
    return Duration(seconds: min(seconds, maxOfflineRetry.inSeconds));
  }

  Timer? _debounce;
  Timer? _next;
  Timer? _reconnect;
  int _offlineAttempts = 0;
  bool _hasNetwork = true;
  bool _syncAgain = false;
  int? _lastEntries;
  bool _ready = false;
  bool _auto = false;
  DateTime? _lastSyncedAt;

  /// Base de la última construcción: si cambia, los datos se borraron.
  LocalSyncStore? _store;

  @override
  SyncState build() {
    ref.onDispose(_cancelTimers);
    _cancelTimers();
    _offlineAttempts = 0;
    _lastEntries = null;
    _hasNetwork = true;
    _syncAgain = false;
    _ready = ref.watch(
      accountSessionProvider.select((s) => s == AccountSessionStatus.ready),
    );
    // Sin sesión lista (cierre de sesión o borrado de los datos locales) se
    // vuelve al estado inicial: la siguiente cuenta no ve la hora de la última
    // sincronización de la anterior.
    if (!_ready) {
      _lastSyncedAt = null;
      return const SyncState();
    }

    _auto = ref.watch(syncAutoTriggersProvider);
    final store = ref.watch(localSyncStoreProvider);
    // Base nueva (el borrado invalida la base): lo mismo, aunque el
    // controlador no se haya reconstruido sin sesión.
    if (!identical(store, _store)) {
      _store = store;
      _lastSyncedAt = null;
    }
    final subscription = store.watchSummary().listen(
      _onQueueChanged,
      onError: (Object _) {},
    );
    ref.onDispose(subscription.cancel);

    if (_auto) {
      final network = ref.watch(networkMonitorProvider);
      final networkChanges = network.watch().listen(
        _onNetworkChanged,
        onError: (Object _) {},
      );
      ref.onDispose(networkChanges.cancel);
      unawaited(
        network.hasNetwork().then((available) {
          if (!available) _onNetworkChanged(false);
        }),
      );
    }

    // Al iniciar sesión o abrir la app con sesión.
    if (_auto) Future.microtask(syncNow);
    return SyncState(lastSyncedAt: _lastSyncedAt);
  }

  /// Sincroniza ahora (deslizar para actualizar, volver a primer plano).
  Future<SyncResult> syncNow() async {
    if (!_ready || !ref.mounted) return SyncResult.skipped;
    _debounce?.cancel();
    final service = ref.read(syncServiceProvider);
    state = state.copyWith(isSyncing: true);
    final result = await service.run();
    if (!ref.mounted) return result;
    _onResult(result);
    return result;
  }

  void onResume() {
    if (_ready) unawaited(syncNow());
  }

  /// Antes de cerrar sesión: intenta enviar todo, durante [timeout] como
  /// máximo, y devuelve cuántos registros quedan sin enviar.
  Future<int> pushBeforeSignOut({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_ready) return 0;
    _cancelTimers();
    final store = ref.read(localSyncStoreProvider);
    try {
      return await ref.read(syncServiceProvider).pushAll().timeout(timeout);
    } on TimeoutException {
      return (await store.summary()).pending;
    } finally {
      // Si el usuario no confirma el cierre, la sincronización sigue.
      if (ref.mounted) _schedule(periodicInterval);
    }
  }

  /// Detiene la sincronización (cierre de sesión o eliminación de la cuenta).
  Future<void> shutdown() async {
    _cancelTimers();
    _ready = false;
    try {
      await ref
          .read(syncServiceProvider)
          .shutdown()
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      // Una solicitud colgada no impide cerrar la sesión.
    }
  }

  void _onQueueChanged(QueueSummary summary) {
    final grew = _lastEntries != null && summary.entries > _lastEntries!;
    _lastEntries = summary.entries;
    if (!ref.mounted) return;
    state = state.copyWith(
      pendingCount: summary.pending,
      rejectedCount: summary.rejected,
    );
    if (grew && _auto && _ready) {
      _debounce?.cancel();
      _debounce = Timer(writeDebounce, () => unawaited(syncNow()));
    }
  }

  /// Sin red: aviso inmediato y sin reintentos (queda el intervalo). Al
  /// recuperarla: una sincronización después de [reconnectDebounce].
  void _onNetworkChanged(bool available) {
    if (!ref.mounted || !_ready) return;
    final recovered = available && !_hasNetwork;
    _hasNetwork = available;
    state = state.copyWith(hasNetwork: available);
    if (!available) {
      _reconnect?.cancel();
      _schedule(periodicInterval);
      return;
    }
    if (!recovered) return;
    _offlineAttempts = 0;
    _reconnect?.cancel();
    _reconnect = Timer(reconnectDebounce, () {
      if (!ref.mounted) return;
      // Si hay una en curso (quizá sin red), se repite al terminar.
      if (state.isSyncing) {
        _syncAgain = true;
      } else {
        unawaited(syncNow());
      }
    });
  }

  void _onResult(SyncResult result) {
    switch (result) {
      case SyncResult.ok:
        _offlineAttempts = 0;
        _lastSyncedAt = ref.read(clockProvider).now();
        state = state.copyWith(
          isSyncing: false,
          lastAttemptOffline: false,
          lastSyncedAt: _lastSyncedAt,
        );
        _schedule(periodicInterval);
      case SyncResult.offline:
        _offlineAttempts++;
        state = state.copyWith(isSyncing: false, lastAttemptOffline: true);
        // Sin red no se reintenta: se espera a que vuelva.
        _schedule(
          _hasNetwork ? offlineRetryDelay(_offlineAttempts) : periodicInterval,
        );
      case SyncResult.unauthorized || SyncResult.failed:
        state = state.copyWith(isSyncing: false);
        _schedule(periodicInterval);
      case SyncResult.skipped:
        state = state.copyWith(isSyncing: false);
    }
    if (_syncAgain) {
      _syncAgain = false;
      unawaited(syncNow());
    }
  }

  void _schedule(Duration delay) {
    if (!_auto || !_ready) return;
    _next?.cancel();
    _next = Timer(delay, () => unawaited(syncNow()));
  }

  void _cancelTimers() {
    _debounce?.cancel();
    _next?.cancel();
    _reconnect?.cancel();
    _debounce = null;
    _next = null;
    _reconnect = null;
  }
}
