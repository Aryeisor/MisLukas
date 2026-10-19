import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/router/app_routes.dart';
import '../../auth/presentation/app_lock/app_lock_controller.dart';
import 'welcome_controller.dart';

/// Abre la bienvenida cuando [WelcomeController] la marca como pendiente. Se
/// monta una sola vez, encima del router (MaterialApp.router builder).
///
/// Usa push y no el redirect del router: el redirect se evalúa con la ruta
/// base y reemplazaría la pila, así que un formulario abierto encima de Inicio
/// se perdería. Con push, la bienvenida queda encima y al cerrarla se vuelve a
/// donde estaba el usuario.
///
/// Durante la recuperación de contraseña la sesión no cuenta como lista, así
/// que no hay sincronización ni bienvenida. Con la app bloqueada, se abre
/// después de desbloquear.
/// La bienvenida está en pantalla, incluso mientras se cierra (su estado ya
/// es [WelcomeStatus.done]). La oferta del bloqueo espera a que se cierre.
final welcomeOpenProvider = NotifierProvider<WelcomeOpenController, bool>(
  WelcomeOpenController.new,
);

class WelcomeOpenController extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool open) {
    if (ref.mounted) state = open;
  }
}

class WelcomeLauncher extends ConsumerWidget {
  const WelcomeLauncher({super.key, required this.child});

  final Widget child;

  void _openIfPending(WidgetRef ref) {
    if (ref.read(welcomeControllerProvider) != WelcomeStatus.pending ||
        !ref.read(appLockProvider).contentVisible) {
      return;
    }
    ref.read(welcomeControllerProvider.notifier).markShowing();
    final open = ref.read(welcomeOpenProvider.notifier)..set(true);
    // push termina cuando la bienvenida se cierra.
    ref
        .read(appRouterProvider)
        .push<void>(AppRoutes.welcome)
        .whenComplete(() => open.set(false));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(welcomeControllerProvider, (_, _) => _openIfPending(ref));
    ref.listen(
      appLockProvider.select((s) => s.contentVisible),
      (_, _) => _openIfPending(ref),
    );
    return child;
  }
}
