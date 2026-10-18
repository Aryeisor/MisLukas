import '../../../../core/utils/date_formatter.dart';
import 'budget_alert.dart';

/// Umbral de una categoría que ya se registró en un mes.
typedef SentBudgetAlert = (String categoryId, BudgetAlertThreshold threshold);

/// Notificación de una alerta de presupuesto. No lleva montos: la notificación
/// puede verse con el celular bloqueado (docs/08).
class BudgetAlertNotice {
  const BudgetAlertNotice({
    required this.categoryId,
    required this.categoryName,
    required this.month,
    required this.percent,
    required this.threshold,
  });

  final String categoryId;
  final String categoryName;

  /// Primer día del mes.
  final DateTime month;
  final int percent;
  final BudgetAlertThreshold threshold;

  /// Título de la notificación.
  static const String title = 'Alerta de presupuesto';

  /// Texto de la notificación: solo el porcentaje, la categoría y el mes.
  String get body => switch (threshold) {
    BudgetAlertThreshold.warning =>
      'Llevas el $percent% de tu presupuesto de $categoryName.',
    BudgetAlertThreshold.exceeded when percent == 100 =>
      'Llegaste al 100% de tu presupuesto de $categoryName de '
          '${DateLabels.monthName(month)}.',
    BudgetAlertThreshold.exceeded =>
      'Superaste tu presupuesto de $categoryName de '
          '${DateLabels.monthName(month)}.',
  };

  @override
  bool operator ==(Object other) =>
      other is BudgetAlertNotice &&
      other.categoryId == categoryId &&
      other.categoryName == categoryName &&
      other.month == month &&
      other.percent == percent &&
      other.threshold == threshold;

  @override
  int get hashCode =>
      Object.hash(categoryId, categoryName, month, percent, threshold);

  @override
  String toString() => 'BudgetAlertNotice($categoryId, ${threshold.name})';
}

/// Lo que falta registrar y notificar de [alerts], dado lo ya registrado en el
/// mes ([sent]).
///
/// Se registran todos los umbrales cruzados que faltan, pero se notifica solo
/// el más alto: un gasto que cruza el 75% y el 100% a la vez avisa solo el
/// 100%. Nada se quita de lo registrado, así que si el gasto baja o el límite
/// sube, el mismo umbral no se repite en el mes.
({List<SentBudgetAlert> toRecord, List<BudgetAlert> toNotify})
pendingBudgetAlerts({
  required Iterable<BudgetAlert> alerts,
  required Set<SentBudgetAlert> sent,
}) {
  final toRecord = <SentBudgetAlert>[];
  final toNotify = <BudgetAlert>[];
  for (final alert in alerts) {
    final missing = [
      for (final threshold in BudgetAlertThreshold.values)
        if (threshold.percent <= alert.threshold.percent &&
            !sent.contains((alert.categoryId, threshold)))
          (alert.categoryId, threshold),
    ];
    if (missing.isEmpty) continue;
    toRecord.addAll(missing);
    // El umbral alcanzado es el más alto; si ya estaba registrado, no se
    // notifica uno menor que faltara.
    if (missing.any((entry) => entry.$2 == alert.threshold)) {
      toNotify.add(alert);
    }
  }
  return (toRecord: toRecord, toNotify: toNotify);
}
