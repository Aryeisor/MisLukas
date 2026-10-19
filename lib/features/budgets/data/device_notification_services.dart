import 'package:permission_handler/permission_handler.dart';

import '../../../core/notifications/local_notifications.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/security/external_activity_tracker.dart';
import '../domain/entities/budget_alert_notice.dart';
import '../domain/repositories/notification_services.dart';

/// Permiso de notificaciones con permission_handler (docs/07 §7.9). El
/// diálogo de permisos y los Ajustes no bloquean la app al volver (docs/07
/// §7.7).
class PermissionHandlerNotificationPermission
    implements NotificationPermissionService {
  const PermissionHandlerNotificationPermission(this._tracker);

  final ExternalActivityTracker _tracker;

  @override
  Future<NotificationPermissionStatus> status() async =>
      _map(await Permission.notification.status);

  @override
  Future<NotificationPermissionStatus> request() async =>
      _map(await _tracker.run(Permission.notification.request));

  @override
  Future<bool> openSettings() {
    _tracker.markLeavingForSettings();
    return openAppSettings();
  }

  static NotificationPermissionStatus _map(PermissionStatus status) =>
      switch (status) {
        PermissionStatus.granted ||
        PermissionStatus.limited ||
        PermissionStatus.provisional => NotificationPermissionStatus.granted,
        PermissionStatus.permanentlyDenied =>
          NotificationPermissionStatus.permanentlyDenied,
        PermissionStatus.restricted => NotificationPermissionStatus.restricted,
        PermissionStatus.denied => NotificationPermissionStatus.denied,
      };
}

/// Alertas de presupuesto como notificaciones locales. El payload es solo la
/// ruta de Presupuestos, sin datos del usuario.
class LocalBudgetAlertNotifier implements BudgetAlertNotifier {
  const LocalBudgetAlertNotifier(this._notifications);

  final LocalNotifications _notifications;

  @override
  Future<void> show(BudgetAlertNotice notice) {
    return _notifications.show(
      id: budgetAlertNotificationId(notice.categoryId, notice.month),
      title: BudgetAlertNotice.title,
      body: notice.body,
      payload: AppRoutes.budgets,
    );
  }

  @override
  Future<void> cancelAll() => _notifications.cancelAll();
}

/// Id estable por categoría y mes (FNV-1a de 31 bits): la notificación del
/// 100% reemplaza a la del 75% de la misma categoría. No usa hashCode, que
/// puede cambiar entre ejecuciones.
int budgetAlertNotificationId(String categoryId, DateTime month) {
  final key =
      '$categoryId|${month.year}-${month.month.toString().padLeft(2, '0')}';
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
