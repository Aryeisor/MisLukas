import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/router/app_routes.dart';
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
/// que no hay sincronización ni bienvenida.
class WelcomeLauncher extends ConsumerWidget {
  const WelcomeLauncher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(welcomeControllerProvider, (_, next) {
      if (next != WelcomeStatus.pending) return;
      ref.read(welcomeControllerProvider.notifier).markShowing();
      ref.read(appRouterProvider).push(AppRoutes.welcome);
    });
    return child;
  }
}
