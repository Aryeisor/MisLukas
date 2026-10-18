import '../entities/budget_alert_notice.dart';

/// Permiso de notificaciones (docs/07 §7.9): POST_NOTIFICATIONS en Android 13
/// o superior; en versiones anteriores viene concedido.
enum NotificationPermissionStatus {
  granted,

  /// Aún se puede pedir con el diálogo del sistema.
  denied,

  /// Negado de forma permanente: solo se habilita en Ajustes.
  permanentlyDenied,

  /// Bloqueado por el sistema (control parental o perfil de trabajo).
  restricted,
}

abstract interface class NotificationPermissionService {
  Future<NotificationPermissionStatus> status();

  /// Muestra el diálogo del sistema si todavía se puede.
  Future<NotificationPermissionStatus> request();

  /// Abre los ajustes de la app. False si no se pudieron abrir.
  Future<bool> openSettings();
}

/// Notificaciones del sistema para las alertas de presupuesto.
abstract interface class BudgetAlertNotifier {
  Future<void> show(BudgetAlertNotice notice);

  /// Quita las notificaciones mostradas (al cerrar sesión).
  Future<void> cancelAll();
}

/// Ajustes de las notificaciones en este dispositivo.
abstract interface class NotificationSettingsRepository {
  /// Interruptor del Perfil. Activadas si el usuario no lo ha cambiado.
  Stream<bool> watchEnabled();

  Future<bool> isEnabled();

  Future<void> setEnabled(bool enabled);

  /// True si la explicación previa del permiso ya se mostró: no se insiste.
  Future<bool> wasExplained();

  Future<void> markExplained();
}
