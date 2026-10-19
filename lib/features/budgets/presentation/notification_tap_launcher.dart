import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/local_notifications.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/app_routes.dart';
import '../../auth/presentation/account_session_controller.dart';
import '../../auth/presentation/app_lock/app_lock_controller.dart';

/// Abre Presupuestos al tocar una notificación de alerta, con la app abierta o
/// cerrada. Se monta una sola vez, encima del router (MaterialApp.router
/// builder), y usa push como la bienvenida: al volver, el usuario sigue donde
/// estaba.
///
/// Espera a que la sesión esté lista y, si la app está bloqueada, a que el
/// usuario la desbloquee (docs/08 §8.8.3.1); sin sesión, el toque se
/// descarta. Solo acepta la ruta de Presupuestos, aunque el payload diga otra
/// cosa.
class NotificationTapLauncher extends ConsumerStatefulWidget {
  const NotificationTapLauncher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationTapLauncher> createState() =>
      _NotificationTapLauncherState();
}

class _NotificationTapLauncherState
    extends ConsumerState<NotificationTapLauncher> {
  StreamSubscription<String>? _taps;
  String? _pending;

  @override
  void initState() {
    super.initState();
    final notifications = ref.read(localNotificationsProvider);
    _pending = _accepted(notifications.takeLaunchPayload());
    _taps = notifications.taps.listen((payload) {
      _pending = _accepted(payload);
      _openIfReady();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _openIfReady());
  }

  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  static String? _accepted(String? payload) =>
      payload == AppRoutes.budgets ? payload : null;

  void _openIfReady() {
    final route = _pending;
    if (route == null || !mounted) return;
    final status = ref.read(accountSessionProvider);
    if (status == AccountSessionStatus.signedOut) {
      _pending = null;
      return;
    }
    if (status != AccountSessionStatus.ready ||
        !ref.read(appLockProvider).contentVisible) {
      return;
    }
    _pending = null;
    ref.read(appRouterProvider).push(route);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(accountSessionProvider, (_, _) => _openIfReady());
    ref.listen(
      appLockProvider.select((s) => s.contentVisible),
      (_, _) => _openIfReady(),
    );
    return widget.child;
  }
}
