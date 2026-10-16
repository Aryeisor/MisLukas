import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/sql_converters.dart';
import '../../../../core/sync/remote_json.dart';
import '../../../../core/sync/sync_status.dart';
import '../../../movements/data/movement_mappers.dart';
import '../../../movements/domain/entities/movement.dart';

/// Fila de la tabla remota `categorias` (supabase/migrations/002).
///
/// Las predeterminadas son filas globales con `usuario_id` null, comunes a
/// todos los usuarios y de solo lectura: la app nunca las envía. Las
/// personalizadas llevan el `usuario_id` de su dueño.
class CategoryDto {
  const CategoryDto({
    required this.id,
    this.userId,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncedAt,
  });

  /// Nombre de la tabla en Supabase.
  static const String table = 'categorias';

  final String id;
  final String? userId;
  final String name;
  final MovementType type;
  final String? icon;
  final String? color;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? syncedAt;

  /// Lanza [FormatException] o [ArgumentError] si una columna no es válida.
  factory CategoryDto.fromJson(Map<String, dynamic> json) {
    final row = RemoteJson(json);
    return CategoryDto(
      id: row.string('id'),
      userId: row.nullableString('usuario_id'),
      name: row.string('nombre'),
      type: movementTypeFromSql(row.string('tipo')),
      icon: row.nullableString('icono'),
      color: row.nullableString('color'),
      createdAt: row.timestamp('creado_en'),
      updatedAt: row.timestamp('actualizado_en'),
      deletedAt: row.nullableTimestamp('eliminado_en'),
      syncedAt: row.nullableTimestamp('sincronizado_en'),
    );
  }

  /// Fila local lista para enviar (solo categorías personalizadas).
  factory CategoryDto.fromRow(CategoryRow row) => CategoryDto(
    id: row.id,
    name: row.name,
    type: movementTypeFromSql(row.type),
    icon: row.icon,
    color: row.color,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
  );

  /// Leída del servidor: es predeterminada si no tiene dueño.
  bool get isDefault => userId == null;

  /// Cuerpo del upsert. Sin `usuario_id` (lo pone el servidor con
  /// auth.uid()) ni `sincronizado_en` (lo asigna un trigger).
  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': name,
    'tipo': movementTypeToSql(type),
    'icono': icon,
    'color': color,
    'creado_en': timestampToRemote(createdAt),
    'actualizado_en': timestampToRemote(updatedAt),
    'eliminado_en': deletedAt == null ? null : timestampToRemote(deletedAt!),
  };

  /// Fila local con lo recibido del servidor, ya sincronizada.
  CategoriesCompanion toCompanion() => CategoriesCompanion.insert(
    id: id,
    name: name,
    type: movementTypeToSql(type),
    icon: Value(icon),
    color: Value(color),
    createdAt: createdAt.toUtc(),
    updatedAt: updatedAt.toUtc(),
    deletedAt: Value(deletedAt?.toUtc()),
    syncStatus: Value(syncStatusSqlValues[SyncStatus.synced]!),
  );
}
