import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/security/device_authenticator.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/app_lock/app_lock_controller.dart';

/// Interruptor "Ingresar con huella, rostro o PIN" del Perfil (RF-46, docs/07
/// §7.7). Controla el bloqueo al reabrir la app y el botón del login con la
/// sesión guardada. Activarlo pide la contraseña de la cuenta y el diálogo del sistema;
/// desactivarlo, solo el diálogo del sistema. Sin bloqueo de pantalla en el
/// celular queda desactivado; al volver a la app se revisa otra vez.
class AppLockSettingsTile extends ConsumerStatefulWidget {
  const AppLockSettingsTile({super.key});

  static const String title = 'Ingresar con huella, rostro o PIN';
  static const String onDescription =
      'Al abrir MisLukas y al volver a entrar en este celular';
  static const String offDescription =
      'Entra sin escribir tu contraseña, con el bloqueo de tu celular';
  static const String noDeviceLockDescription =
      'Configura un bloqueo de pantalla en tu celular para proteger MisLukas';
  static const String disabledMessage =
      'Ingreso con huella, rostro o PIN desactivado';
  static const String stillOnMessage =
      'El ingreso con huella, rostro o PIN sigue activo.';
  static const String lockedOutMessage =
      'Tu celular pausó el desbloqueo por varios intentos fallidos. Espera un '
      'momento e inténtalo de nuevo.';

  @override
  ConsumerState<AppLockSettingsTile> createState() =>
      _AppLockSettingsTileState();
}

class _AppLockSettingsTileState extends ConsumerState<AppLockSettingsTile> {
  late final AppLifecycleListener _lifecycle;

  AppLockController get _controller => ref.read(appLockProvider.notifier);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => _controller.refreshDeviceLock(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.refreshDeviceLock();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _toggle(bool on) async {
    if (on) {
      await context.push(AppRoutes.appLock);
      return;
    }
    final result = await _controller.disable();
    if (!mounted) return;
    switch (result) {
      case DeviceAuthResult.success:
        AppSnackbar.info(context, AppLockSettingsTile.disabledMessage);
      case DeviceAuthResult.lockedOut:
        AppSnackbar.error(context, AppLockSettingsTile.lockedOutMessage);
      case DeviceAuthResult.canceled ||
          DeviceAuthResult.interrupted ||
          DeviceAuthResult.noDeviceLock ||
          DeviceAuthResult.failed:
        AppSnackbar.info(context, AppLockSettingsTile.stillOnMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockProvider);
    final available = lock.deviceLockAvailable;
    return AppSwitchTile(
      title: AppLockSettingsTile.title,
      subtitle: available == false
          ? AppLockSettingsTile.noDeviceLockDescription
          : lock.enabled
          ? AppLockSettingsTile.onDescription
          : AppLockSettingsTile.offDescription,
      icon: Icons.lock_outline,
      value: lock.enabled && available == true,
      onChanged: available == true && !lock.authenticating ? _toggle : null,
    );
  }
}
