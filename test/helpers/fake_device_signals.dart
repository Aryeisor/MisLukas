import 'dart:async';

import 'package:mislukas/core/sync/network_monitor.dart';
import 'package:mislukas/features/budgets/domain/entities/budget_alert_notice.dart';
import 'package:mislukas/features/budgets/domain/repositories/notification_services.dart';

/// Permiso de notificaciones falso: [current] es el estado actual y
/// [onRequest] lo que responde el diálogo del sistema. Por defecto concedido,
/// para que guardar un presupuesto no muestre la explicación previa.
class FakeNotificationPermission implements NotificationPermissionService {
  FakeNotificationPermission({
    this.current = NotificationPermissionStatus.granted,
    this.onRequest = NotificationPermissionStatus.granted,
  });

  NotificationPermissionStatus current;
  NotificationPermissionStatus onRequest;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<NotificationPermissionStatus> status() async => current;

  @override
  Future<NotificationPermissionStatus> request() async {
    requests++;
    current = onRequest;
    return current;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

/// Notificaciones falsas: guarda lo que se mostró.
class FakeBudgetAlertNotifier implements BudgetAlertNotifier {
  final List<BudgetAlertNotice> shown = [];
  int cancelled = 0;

  /// Hace fallar las notificaciones.
  bool fail = false;

  @override
  Future<void> show(BudgetAlertNotice notice) async {
    if (fail) throw StateError('Fallo simulado al notificar');
    shown.add(notice);
  }

  @override
  Future<void> cancelAll() async => cancelled++;
}

/// Señal de red falsa: [set] simula conectarse o desconectarse.
class FakeNetworkMonitor implements NetworkMonitor {
  FakeNetworkMonitor({this.available = true});

  bool available;
  final StreamController<bool> _changes = StreamController.broadcast();

  void set(bool value) {
    available = value;
    _changes.add(value);
  }

  @override
  Future<bool> hasNetwork() async => available;

  @override
  Stream<bool> watch() => _changes.stream;
}
