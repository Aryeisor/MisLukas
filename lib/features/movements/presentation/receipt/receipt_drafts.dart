import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/account_session_controller.dart';
import '../../data/movements_providers.dart';

/// Ids de los recibos en curso: desde que se toma la foto hasta que el gasto
/// se guarda o se descarta. Sus imágenes todavía no tienen fila en la base y
/// la limpieza no las toca.
final receiptDraftsInProgressProvider =
    NotifierProvider<ReceiptDraftsInProgress, Set<String>>(
      ReceiptDraftsInProgress.new,
    );

class ReceiptDraftsInProgress extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void add(String receiptId) => state = {...state, receiptId};

  void remove(String receiptId) {
    if (!state.contains(receiptId)) return;
    state = {...state}..remove(receiptId);
  }
}

/// La limpieza ya corrió en este arranque de la app.
final receiptCleanupDoneProvider = NotifierProvider<ReceiptCleanupDone, bool>(
  ReceiptCleanupDone.new,
);

class ReceiptCleanupDone extends Notifier<bool> {
  @override
  bool build() => false;

  void markDone() => state = true;
}

final receiptCleanupProvider = NotifierProvider<ReceiptCleanupController, int>(
  ReceiptCleanupController.new,
);

/// Borra las imágenes de recibos huérfanas (CleanReceiptImages) una sola vez
/// por arranque: la primera vez que la sesión queda lista, antes de que se
/// pueda abrir la captura. Si la sesión vuelve a quedar lista (otro inicio de
/// sesión), no se repite. Nunca toca los recibos en curso.
///
/// El estado cuenta las ejecuciones terminadas (para las pruebas).
class ReceiptCleanupController extends Notifier<int> {
  int _runs = 0;

  @override
  int build() {
    final ready = ref.watch(
      accountSessionProvider.select((s) => s == AccountSessionStatus.ready),
    );
    if (ready && !ref.read(receiptCleanupDoneProvider)) {
      // No se modifica otro provider mientras este se construye.
      Future.microtask(_run);
    }
    return _runs;
  }

  Future<void> _run() async {
    if (!ref.mounted || ref.read(receiptCleanupDoneProvider)) return;
    ref.read(receiptCleanupDoneProvider.notifier).markDone();
    try {
      await ref
          .read(cleanReceiptImagesProvider)
          .call(inProgress: ref.read(receiptDraftsInProgressProvider));
    } catch (_) {
      // Sin log (rutas del dispositivo): en el próximo arranque se intenta
      // de nuevo.
    } finally {
      _runs++;
      if (ref.mounted) state = _runs;
    }
  }
}
