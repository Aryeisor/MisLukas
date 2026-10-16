import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/sql_converters.dart';
import '../../../../core/sync/remote_json.dart';
import '../../../../core/sync/sync_status.dart';

/// Fila de la tabla remota `presupuestos` (supabase/migrations/004).
class BudgetDto {
  const BudgetDto({
    required this.id,
    this.userId,
    required this.categoryId,
    required this.month,
    required this.limitAmount,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncedAt,
  });

  /// Nombre de la tabla en Supabase.
  static const String table = 'presupuestos';

  final String id;
  final String? userId;
  final String categoryId;

  /// Primer día del mes.
  final DateTime month;
  final int limitAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? syncedAt;

  /// Lanza [FormatException] si una columna no es válida.
  factory BudgetDto.fromJson(Map<String, dynamic> json) {
    final row = RemoteJson(json);
    return BudgetDto(
      id: row.string('id'),
      userId: row.nullableString('usuario_id'),
      categoryId: row.string('categoria_id'),
      month: row.date('mes'),
      limitAmount: row.integer('monto_limite'),
      createdAt: row.timestamp('creado_en'),
      updatedAt: row.timestamp('actualizado_en'),
      deletedAt: row.nullableTimestamp('eliminado_en'),
      syncedAt: row.nullableTimestamp('sincronizado_en'),
    );
  }

  /// Fila local lista para enviar.
  factory BudgetDto.fromRow(BudgetRow row) => BudgetDto(
    id: row.id,
    categoryId: row.categoryId,
    month: row.month,
    limitAmount: row.limitAmount,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
  );

  /// Cuerpo del upsert. Sin `usuario_id` (lo pone el servidor con
  /// auth.uid()) ni `sincronizado_en` (lo asigna un trigger).
  Map<String, dynamic> toJson() => {
    'id': id,
    'categoria_id': categoryId,
    'mes': dateToRemote(month),
    'monto_limite': limitAmount,
    'creado_en': timestampToRemote(createdAt),
    'actualizado_en': timestampToRemote(updatedAt),
    'eliminado_en': deletedAt == null ? null : timestampToRemote(deletedAt!),
  };

  /// Fila local con lo recibido del servidor, ya sincronizada.
  BudgetsCompanion toCompanion() => BudgetsCompanion.insert(
    id: id,
    categoryId: categoryId,
    month: month,
    limitAmount: limitAmount,
    createdAt: createdAt.toUtc(),
    updatedAt: updatedAt.toUtc(),
    deletedAt: Value(deletedAt?.toUtc()),
    syncStatus: Value(syncStatusSqlValues[SyncStatus.synced]!),
  );
}
