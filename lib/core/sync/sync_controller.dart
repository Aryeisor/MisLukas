import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/account_session_controller.dart';
import '../utils/utils_providers.dart';
import 'local_sync_store.dart';
import 'sync_providers.dart';
import 'sync_service.dart';

/// Estado de la sincronización para la interfaz (docs/05 §5.3, RF-47).
class SyncState {
  const SyncState({
    this.isSyncing = false,
    this.isOffline = false,
    this.pendingCount = 0,
    this.rejectedCount = 0,
    this.lastSyncedAt,
  });

  final bool isSyncing;

  /// El último intento falló por la red.
  final bool isOffline;

  /// Registros con cambios sin enviar.
  final int pendingCount;

  /// Registros que el servidor rechazó y esperan su próximo intento.
  final int rejectedCount;

  /// Última sincronización completa en este dispositivo (hora local).
  final DateTime? lastSyncedAt;

  SyncState copyWith({
    bool? isSyncing,
    bool? isOffline,
    int? pendingCount,
    int? rejectedCount,
    DateTime? lastSyncedAt,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      isOffline: isOffline ?? this.isOffline,
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
/// - sin conexión, con esperas crecientes hasta [maxOfflineRetry].
///
/// connectivity_plus llega en la Fase 6: por ahora "sin conexión" es el
/// resultado del último intento.
class SyncController extends Notifier<SyncState> {
  /// Espera después de una escritura local.
  static const Duration writeDebounce = Duration(seconds: 2);

  /// Sincronización periódica con la app abierta (docs/06 §6.6.2).
  static const Duration periodicInterval = Duration(minutes: 5);

  /// Espera máxima entre intentos sin conexión: con ella los cambios llegan
  /// en menos de un minuto después de recuperar la conexión (RNF-10).
  static const Duration maxOfflineRetry = Duration(seconds: 60);

  /// Espera antes del intento [attempt] sin conexión: 5, 10, 20, 40 y 60 s.
  static Duration offlineRetryDelay(int attempt) {
    final seconds = 5 * pow(2, (attempt - 1).clamp(0, 10)).toInt();
    return Duration(seconds: min(seconds, maxOfflineRetry.inSeconds));
  }

  Timer? _debounce;
  Timer? _next;
  int _offlineAttempts = 0;
  int? _lastEntries;
  bool _ready = false;
  bool _auto = false;
  DateTime? _lastSyncedAt;

  @override
  SyncState build() {
    ref.onDispose(_cancelTimers);
    _cancelTimers();
    _offlineAttempts = 0;
    _lastEntries = null;
    _ready = ref.watch(
      accountSessionProvider.select((s) => s == AccountSessionStatus.ready),
    );
    if (!_ready) return const SyncState();

    _auto = ref.watch(syncAutoTriggersProvider);
    final subscription = ref
        .watch(localSyncStoreProvider)
        .watchSummary()
        .listen(_onQueueChanged, onError: (Object _) {});
    ref.onDispose(subscription.cancel);

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

  void _onResult(SyncResult result) {
    switch (result) {
      case SyncResult.ok:
        _offlineAttempts = 0;
        _lastSyncedAt = ref.read(clockProvider).now();
        state = state.copyWith(
          isSyncing: false,
          isOffline: false,
          lastSyncedAt: _lastSyncedAt,
        );
        _schedule(periodicInterval);
      case SyncResult.offline:
        _offlineAttempts++;
        state = state.copyWith(isSyncing: false, isOffline: true);
        _schedule(offlineRetryDelay(_offlineAttempts));
      case SyncResult.unauthorized || SyncResult.failed:
        state = state.copyWith(isSyncing: false);
        _schedule(periodicInterval);
      case SyncResult.skipped:
        state = state.copyWith(isSyncing: false);
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
    _debounce = null;
    _next = null;
  }
}
