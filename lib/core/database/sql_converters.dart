import 'package:drift/drift.dart';

import '../sync/sync_status.dart';

/// Fecha sin hora guardada como texto 'AAAA-MM-DD', igual que el tipo `date`
/// de PostgreSQL. Al ser texto con ceros a la izquierda, se compara en orden.
class SqlDateConverter extends TypeConverter<DateTime, String> {
  const SqlDateConverter();

  @override
  DateTime fromSql(String fromDb) => DateTime.parse(fromDb);

  @override
  String toSql(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

/// Valores de la columna `estado_sync`.
const Map<SyncStatus, String> syncStatusSqlValues = {
  SyncStatus.synced: 'sincronizado',
  SyncStatus.pending: 'pendiente',
  SyncStatus.error: 'error',
};

SyncStatus syncStatusFromSql(String value) => syncStatusSqlValues.entries
    .firstWhere(
      (entry) => entry.value == value,
      orElse: () => throw ArgumentError.value(value, 'estado_sync'),
    )
    .key;
