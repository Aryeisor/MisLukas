import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/sql_converters.dart';
import '../../../../core/sync/remote_json.dart';
import '../../../../core/sync/sync_status.dart';
import '../../domain/entities/movement.dart';
import '../movement_mappers.dart';

/// Fila de la tabla remota `movimientos` (supabase/migrations/003).
///
/// [userId] y [syncedAt] los asigna el servidor: se leen pero nunca se
/// envían.
class MovementDto {
  const MovementDto({
    required this.id,
    this.userId,
    required this.categoryId,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
    this.note,
    required this.origin,
    required this.account,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncedAt,
  });

  /// Nombre de la tabla en Supabase.
  static const String table = 'movimientos';

  final String id;
  final String? userId;
  final String categoryId;
  final MovementType type;
  final int amount;
  final DateTime date;
  final String description;
  final String? note;
  final MovementOrigin origin;
  final String account;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? syncedAt;

  /// Lanza [FormatException] o [ArgumentError] si una columna no es válida.
  factory MovementDto.fromJson(Map<String, dynamic> json) {
    final row = RemoteJson(json);
    return MovementDto(
      id: row.string('id'),
      userId: row.nullableString('usuario_id'),
      categoryId: row.string('categoria_id'),
      type: movementTypeFromSql(row.string('tipo')),
      amount: row.integer('monto'),
      date: row.date('fecha'),
      description: row.string('descripcion'),
      note: row.nullableString('nota'),
      origin: movementOriginFromSql(row.string('origen')),
      account: row.string('cuenta'),
      createdAt: row.timestamp('creado_en'),
      updatedAt: row.timestamp('actualizado_en'),
      deletedAt: row.nullableTimestamp('eliminado_en'),
      syncedAt: row.nullableTimestamp('sincronizado_en'),
    );
  }

  /// Fila local lista para enviar.
  factory MovementDto.fromRow(MovementRow row) => MovementDto(
    id: row.id,
    categoryId: row.categoryId,
    type: movementTypeFromSql(row.type),
    amount: row.amount,
    date: row.date,
    description: row.description,
    note: row.note,
    origin: movementOriginFromSql(row.origin),
    account: row.account,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
  );

  /// Cuerpo del upsert. Sin `usuario_id` (lo pone el servidor con
  /// auth.uid()) ni `sincronizado_en` (lo asigna un trigger).
  Map<String, dynamic> toJson() => {
    'id': id,
    'categoria_id': categoryId,
    'tipo': movementTypeToSql(type),
    'monto': amount,
    'fecha': dateToRemote(date),
    'descripcion': description,
    'nota': note,
    'origen': movementOriginToSql(origin),
    'cuenta': account,
    'creado_en': timestampToRemote(createdAt),
    'actualizado_en': timestampToRemote(updatedAt),
    'eliminado_en': deletedAt == null ? null : timestampToRemote(deletedAt!),
  };

  /// Fila local con lo recibido del servidor, ya sincronizada.
  MovementsCompanion toCompanion() => MovementsCompanion.insert(
    id: id,
    categoryId: categoryId,
    type: movementTypeToSql(type),
    amount: amount,
    date: date,
    description: description,
    note: Value(note),
    origin: movementOriginToSql(origin),
    account: Value(account),
    createdAt: createdAt.toUtc(),
    updatedAt: updatedAt.toUtc(),
    deletedAt: Value(deletedAt?.toUtc()),
    syncStatus: Value(syncStatusSqlValues[SyncStatus.synced]!),
  );
}
