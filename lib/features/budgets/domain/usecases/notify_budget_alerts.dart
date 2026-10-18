import '../../../../core/utils/clock.dart';
import '../entities/budget_alert_notice.dart';
import '../repositories/budget_alert_log.dart';
import '../repositories/category_repository.dart';
import '../repositories/notification_services.dart';
import 'evaluate_budget_alerts.dart';

/// Notifica las alertas de presupuesto del mes actual que aún no se han
/// registrado (RF-32): una sola vez por categoría, umbral y mes.
///
/// - La primera vez en una base (línea base) registra lo ya cruzado sin
///   notificar: lo que llega en la primera sincronización no es nuevo.
/// - Registra antes de notificar: una alerta se muestra como mucho una vez,
///   aunque la notificación falle.
/// - Sin el interruptor del Perfil o sin permiso registra igual, para que al
///   activarlas no lleguen avisos viejos. Dentro de la app las alertas se ven
///   siempre (Inicio).
/// - Solo evalúa el mes actual: cambiar un gasto de un mes pasado no notifica.
class NotifyBudgetAlerts {
  const NotifyBudgetAlerts({
    required this._evaluate,
    required this._log,
    required this._categories,
    required this._settings,
    required this._permission,
    required this._notifier,
    required this._clock,
  });

  final EvaluateBudgetAlerts _evaluate;
  final BudgetAlertLog _log;
  final CategoryRepository _categories;
  final NotificationSettingsRepository _settings;
  final NotificationPermissionService _permission;
  final BudgetAlertNotifier _notifier;
  final Clock _clock;

  /// Devuelve las notificaciones mostradas.
  Future<List<BudgetAlertNotice>> call() async {
    final now = _clock.now();
    final month = monthStart(now);
    final alerts = await _evaluate(month: month);
    final pending = pendingBudgetAlerts(
      alerts: alerts,
      sent: await _log.sentFor(month),
    );
    final hasBaseline = await _log.hasBaseline();
    if (pending.toRecord.isNotEmpty) {
      await _log.record(month, pending.toRecord, at: now);
    }
    if (!hasBaseline) {
      await _log.markBaseline();
      return const [];
    }
    if (pending.toNotify.isEmpty) return const [];
    if (!await _settings.isEnabled()) return const [];
    if (await _permission.status() != NotificationPermissionStatus.granted) {
      return const [];
    }

    final shown = <BudgetAlertNotice>[];
    for (final alert in pending.toNotify) {
      final category = await _categories.findById(alert.categoryId);
      final notice = BudgetAlertNotice(
        categoryId: alert.categoryId,
        categoryName: category?.name ?? 'esta categoría',
        month: month,
        percent: alert.percent,
        threshold: alert.threshold,
      );
      try {
        await _notifier.show(notice);
        shown.add(notice);
      } catch (_) {
        // Ya quedó registrada: no se reintenta.
      }
    }
    return shown;
  }
}
