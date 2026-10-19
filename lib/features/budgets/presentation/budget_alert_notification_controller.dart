import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_controller.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/utils_providers.dart';
import '../../auth/presentation/account_session_controller.dart';
import '../data/budgets_providers.dart';

final budgetAlertNotificationProvider =
    NotifierProvider<BudgetAlertNotificationController, int>(
      BudgetAlertNotificationController.new,
    );

/// Notifica las alertas de presupuesto del mes (RF-32) cada vez que cambian
/// los gastos o los presupuestos del mes: al registrar, editar o eliminar un
/// gasto, al crear, cambiar o quitar un presupuesto y cuando el pull trae
/// datos de otro celular. También evalúa después de cada sincronización.
///
/// No hay trabajo en segundo plano: solo evalúa con la app abierta.
///
/// No evalúa nada hasta la primera sincronización exitosa de la sesión, salvo
/// que la base ya tenga la línea base: así la línea base se toma con los
/// datos del servidor y lo que llega en el primer pull no se notifica.
///
/// Observa el reloj: "Adelantar un mes" (solo en desarrollo) evalúa el mes
/// nuevo. Si el mes cambia con la app abierta, se reinicia en la siguiente
/// sincronización (cada 5 minutos como máximo).
///
/// El estado cuenta las evaluaciones terminadas (para las pruebas).
class BudgetAlertNotificationController extends Notifier<int> {
  bool _running = false;
  bool _runAgain = false;
  DateTime? _month;

  @override
  int build() {
    final ready = ref.watch(
      accountSessionProvider.select((s) => s == AccountSessionStatus.ready),
    );
    // Se reconstruye con la base: al borrar los datos locales, empieza de nuevo.
    ref.watch(budgetRepositoryProvider);
    final clock = ref.watch(clockProvider);
    if (!ready) return 0;

    final month = monthStart(clock.now());
    _month = month;
    final subscription = ref
        .read(watchBudgetAlertsProvider)
        .call(month: month)
        .listen((_) => _run(), onError: (Object _) {});
    ref.onDispose(subscription.cancel);

    ref.listen(syncControllerProvider.select((s) => s.isSyncing), (
      previous,
      next,
    ) {
      if (previous == true && !next) _afterSync();
    });
    return 0;
  }

  /// Si el mes cambió con la app abierta, se reinicia con el mes nuevo.
  void _afterSync() {
    if (monthStart(ref.read(clockProvider).now()) != _month) {
      ref.invalidateSelf();
      return;
    }
    _run();
  }

  /// Una evaluación a la vez; los cambios que llegan mientras corre se evalúan
  /// en una sola pasada al terminar.
  Future<void> _run() async {
    if (_running) {
      _runAgain = true;
      return;
    }
    _running = true;
    try {
      do {
        _runAgain = false;
        if (!ref.mounted) return;
        // lastSyncedAt es de esta sesión: vuelve a null al cerrar sesión o
        // al borrar los datos locales.
        final synced = ref.read(syncControllerProvider).lastSyncedAt != null;
        if (!synced && !await ref.read(budgetAlertLogProvider).hasBaseline()) {
          continue;
        }
        if (!ref.mounted) return;
        await ref.read(notifyBudgetAlertsProvider).call();
      } while (_runAgain);
    } catch (_) {
      // Sin log (puede incluir datos del usuario): se evalúa en el próximo
      // cambio o sincronización.
    } finally {
      _running = false;
      if (ref.mounted) state = state + 1;
    }
  }
}
