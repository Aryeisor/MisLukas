import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_controller.dart';
import '../../auth/presentation/account_session_controller.dart';
import '../data/budgets_providers.dart';

final budgetCarryOverProvider =
    NotifierProvider<BudgetCarryOverController, int>(
      BudgetCarryOverController.new,
    );

/// Continúa los presupuestos en el mes nuevo (RF-53) después de cada intento
/// de sincronización, salga bien o no: al abrir la app, al volver a primer
/// plano y cada 5 minutos, así que también cubre el cambio de mes con la app
/// abierta.
///
/// Corre después y no antes del intento: con conexión, el pull ya trajo los
/// presupuestos que otro celular copió y no se copia otra vez. Sin conexión
/// copia igual; si dos celulares copian el mismo mes, la sincronización deja
/// uno por categoría.
///
/// El estado cuenta las ejecuciones terminadas (para las pruebas).
class BudgetCarryOverController extends Notifier<int> {
  bool _running = false;

  @override
  int build() {
    final ready = ref.watch(
      accountSessionProvider.select((s) => s == AccountSessionStatus.ready),
    );
    // Se reconstruye con la base: al borrar los datos locales, empieza de nuevo.
    ref.watch(budgetRepositoryProvider);
    if (!ready) return 0;

    ref.listen(syncControllerProvider.select((s) => s.isSyncing), (
      previous,
      next,
    ) {
      if (previous == true && !next) _run();
    });
    return 0;
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    try {
      await ref.read(carryOverBudgetsProvider).call();
    } catch (_) {
      // Sin log (puede incluir datos del usuario): se intenta en la próxima
      // sincronización.
    } finally {
      _running = false;
      if (ref.mounted) state = state + 1;
    }
  }
}
