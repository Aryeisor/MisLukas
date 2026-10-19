import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/entities/budget_alert.dart';
import '../domain/entities/budget_alert_notice.dart';
import '../domain/repositories/budget_alert_log.dart';

/// Clave de la línea base de las alertas en ajustes_locales.
const String alertsBaselineSettingKey = 'alertas_linea_base';

/// Valor de [alertsBaselineSettingKey] cuando la línea base ya se tomó.
const String alertsBaselineDoneValue = 'lista';

/// Registro de alertas en la base local (tabla alertas_enviadas). No se
/// sincroniza y se borra con la base al cerrar sesión.
class DriftBudgetAlertLog implements BudgetAlertLog {
  DriftBudgetAlertLog(this._db);

  final AppDatabase _db;

  @override
  Future<Set<SentBudgetAlert>> sentFor(DateTime month) async {
    final rows = await (_db.select(
      _db.sentBudgetAlerts,
    )..where((t) => t.month.equalsValue(month))).get();
    return {
      for (final row in rows)
        if (_thresholdOf(row.threshold) case final threshold?)
          (row.categoryId, threshold),
    };
  }

  @override
  Future<void> record(
    DateTime month,
    Iterable<SentBudgetAlert> entries, {
    required DateTime at,
  }) {
    return _db.batch((batch) {
      batch.insertAll(_db.sentBudgetAlerts, [
        for (final (categoryId, threshold) in entries)
          SentBudgetAlertsCompanion.insert(
            categoryId: categoryId,
            month: month,
            threshold: threshold.percent,
            sentAt: at.toUtc(),
          ),
      ], mode: InsertMode.insertOrIgnore);
    });
  }

  @override
  Future<bool> hasBaseline() async {
    final row = await (_db.select(
      _db.localSettings,
    )..where((t) => t.key.equals(alertsBaselineSettingKey))).getSingleOrNull();
    return row?.value == alertsBaselineDoneValue;
  }

  @override
  Future<void> markBaseline() {
    return _db
        .into(_db.localSettings)
        .insertOnConflictUpdate(
          LocalSettingsCompanion.insert(
            key: alertsBaselineSettingKey,
            value: alertsBaselineDoneValue,
          ),
        );
  }

  static BudgetAlertThreshold? _thresholdOf(int percent) {
    for (final threshold in BudgetAlertThreshold.values) {
      if (threshold.percent == percent) return threshold;
    }
    return null;
  }
}
