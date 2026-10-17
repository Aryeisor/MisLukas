import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_controller.dart';
import '../../auth/presentation/account_session_controller.dart';
import '../data/onboarding_providers.dart';

/// Estado de la bienvenida en esta sesión (RF-51).
enum WelcomeStatus {
  /// Aún no se sabe: falta una sincronización exitosa.
  unknown,

  /// Usuario nuevo: hay que mostrarla.
  pending,

  /// Está abierta.
  showing,

  /// Ya se completó, se omitió o no hace falta (el usuario tiene datos).
  done,
}

final welcomeControllerProvider =
    NotifierProvider<WelcomeController, WelcomeStatus>(WelcomeController.new);

/// Decide si se muestra la bienvenida. "Usuario nuevo" es el que no tiene
/// ningún dato propio (movimientos, presupuestos ni categorías) después de la
/// primera sincronización exitosa de la sesión: así, quien ya tiene datos en
/// el servidor y entra desde un celular nuevo no la ve, porque el pull ya los
/// descargó.
///
/// Sin conexión no decide nada: espera a que una sincronización salga bien.
/// Si mientras tanto el usuario registra algo, ya tiene datos y no se muestra.
/// La decisión se guarda en la base local (ajustes_locales), que se borra con
/// los datos locales.
class WelcomeController extends Notifier<WelcomeStatus> {
  @override
  WelcomeStatus build() {
    final ready = ref.watch(
      accountSessionProvider.select((s) => s == AccountSessionStatus.ready),
    );
    // Se reconstruye con la base: al borrar los datos locales, empieza de nuevo.
    ref.watch(onboardingRepositoryProvider);
    if (!ready) return WelcomeStatus.unknown;

    // Solo cuenta una sincronización que termina después de este punto: un
    // lastSyncedAt de una sesión anterior no dispara nada.
    ref.listen(syncControllerProvider.select((s) => s.lastSyncedAt), (
      previous,
      next,
    ) {
      if (next != null && next != previous) _evaluate();
    });
    Future.microtask(_loadMark);
    return WelcomeStatus.unknown;
  }

  Future<void> _loadMark() async {
    try {
      final done = await ref.read(onboardingRepositoryProvider).isWelcomeDone();
      if (!ref.mounted) return;
      if (done) state = WelcomeStatus.done;
    } catch (_) {
      // Sin la marca, se decide en la próxima sincronización.
    }
  }

  Future<void> _evaluate() async {
    if (state != WelcomeStatus.unknown) return;
    final repository = ref.read(onboardingRepositoryProvider);
    try {
      if (await repository.isWelcomeDone()) {
        if (ref.mounted) state = WelcomeStatus.done;
        return;
      }
      if (await repository.hasOwnData()) {
        // Usuario con datos: la bienvenida ya no sale en este dispositivo.
        await repository.markWelcomeDone();
        if (ref.mounted) state = WelcomeStatus.done;
        return;
      }
      if (ref.mounted && state == WelcomeStatus.unknown) {
        state = WelcomeStatus.pending;
      }
    } catch (_) {
      // Error de la base: se intenta en la próxima sincronización.
    }
  }

  /// La pantalla se abrió: no se vuelve a abrir en esta sesión.
  void markShowing() {
    if (state == WelcomeStatus.pending) state = WelcomeStatus.showing;
  }

  /// Se terminó u omitió: se guarda la marca y no vuelve a salir.
  Future<void> complete() async {
    state = WelcomeStatus.done;
    try {
      await ref.read(onboardingRepositoryProvider).markWelcomeDone();
    } catch (_) {
      // Sin la marca, puede volver a salir; si el usuario ya registró algo,
      // tiene datos y no sale.
    }
  }
}
