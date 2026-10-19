import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/sync/sync_controller.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../onboarding/presentation/welcome_controller.dart';
import '../../../onboarding/presentation/welcome_launcher.dart';
import '../account_session_controller.dart';
import 'app_lock_controller.dart';

/// Ofrece activar el bloqueo después de iniciar sesión o de registrarse con
/// contraseña (docs/07 §7.7), después de la primera sincronización exitosa
/// de la sesión, cuando la bienvenida ya terminó o no hacía falta. Para
/// entonces el usuario ya salió del login: el diálogo no se pierde con la
/// redirección. Si la bienvenida sigue abierta (está cerrándose), espera a
/// que se cierre: así su cierre no se lleva el diálogo.
///
/// Como el usuario acaba de escribir su contraseña, "Activar" solo guarda la
/// preferencia, sin el diálogo del sistema (no debe sentirse como un segundo
/// factor); el bloqueo aplica desde la siguiente apertura o regreso. Sin
/// bloqueo de pantalla en el celular, no se ofrece. "Ahora no" no vuelve a
/// preguntar hasta el próximo inicio de sesión. Si el bloqueo ya estaba
/// activo en este celular, no se ofrece.
///
/// Se monta una sola vez, encima del router (MaterialApp.router builder).
class AppLockOfferLauncher extends ConsumerStatefulWidget {
  const AppLockOfferLauncher({super.key, required this.child});

  final Widget child;

  static const String title = 'Ingresa con tu huella, rostro o PIN';
  static const String message =
      'La próxima vez que abras MisLukas o vuelvas a entrar, usarás la huella, '
      'el rostro o el PIN de tu celular. No tienes que crear otra clave.';
  static const String enabledMessage =
      'Listo. La próxima vez entrarás con tu huella, rostro o el PIN de tu '
      'celular.';
  static const String notEnabledMessage =
      'No se activó. Puedes activarlo desde tu Perfil.';

  @override
  ConsumerState<AppLockOfferLauncher> createState() =>
      _AppLockOfferLauncherState();
}

class _AppLockOfferLauncherState extends ConsumerState<AppLockOfferLauncher> {
  bool _offering = false;

  bool get _due {
    final lock = ref.read(appLockProvider);
    return lock.offerPending &&
        !lock.enabled &&
        lock.contentVisible &&
        ref.read(accountSessionProvider) == AccountSessionStatus.ready &&
        ref.read(syncControllerProvider).lastSyncedAt != null &&
        ref.read(welcomeControllerProvider) == WelcomeStatus.done &&
        !ref.read(welcomeOpenProvider);
  }

  Future<void> _offerIfDue() async {
    if (_offering || !_due) return;
    _offering = true;
    try {
      final controller = ref.read(appLockProvider.notifier);
      final hasLock = await controller.refreshDeviceLock();
      if (!mounted || !_due) return;
      // Se ofrece una sola vez por inicio de sesión.
      controller.dismissOffer();
      if (!hasLock) return;
      final navigatorContext = ref
          .read(rootNavigatorKeyProvider)
          .currentContext;
      if (navigatorContext == null || !navigatorContext.mounted) return;
      final accepted = await showAppConfirmDialog(
        navigatorContext,
        title: AppLockOfferLauncher.title,
        message: AppLockOfferLauncher.message,
        confirmLabel: 'Activar',
        cancelLabel: 'Ahora no',
      );
      if (!accepted || !mounted) return;
      final enabled = await controller.enableAfterSignIn();
      if (!navigatorContext.mounted) return;
      if (enabled) {
        AppSnackbar.success(
          navigatorContext,
          AppLockOfferLauncher.enabledMessage,
        );
      } else {
        AppSnackbar.info(
          navigatorContext,
          AppLockOfferLauncher.notEnabledMessage,
        );
      }
    } finally {
      _offering = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appLockProvider, (_, _) => _offerIfDue());
    ref.listen(welcomeControllerProvider, (_, _) => _offerIfDue());
    ref.listen(welcomeOpenProvider, (_, _) => _offerIfDue());
    ref.listen(accountSessionProvider, (_, _) => _offerIfDue());
    ref.listen(
      syncControllerProvider.select((s) => s.lastSyncedAt),
      (_, _) => _offerIfDue(),
    );
    return widget.child;
  }
}
