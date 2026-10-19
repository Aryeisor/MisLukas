import '../entities/budget_alert_notice.dart';

/// Alertas de presupuesto ya registradas en este dispositivo: una por
/// categoría, umbral y mes.
abstract interface class BudgetAlertLog {
  /// Lo registrado en el mes de [month] (primer día).
  Future<Set<SentBudgetAlert>> sentFor(DateTime month);

  /// Registra [entries] en el mes de [month]. Lo ya registrado no cambia.
  Future<void> record(
    DateTime month,
    Iterable<SentBudgetAlert> entries, {
    required DateTime at,
  });

  /// True si ya se tomó la línea base: lo cruzado antes de la primera
  /// sincronización de esta base se registró sin notificar.
  Future<bool> hasBaseline();

  Future<void> markBaseline();
}
