import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/sql_converters.dart';
import '../../../../core/sync/remote_json.dart';
import '../../../../core/sync/sync_status.dart';

/// Fila de la tabla remota `recibos` (supabase/migrations/005).
///
/// La ruta local de la imagen no sale del dispositivo. En el servidor solo
/// existe [storagePath], la ubicación en Storage si el usuario respalda sus
/// recibos ({usuario_id}/{id}.jpg).
class ReceiptDto {
  const ReceiptDto({
    required this.id,
    this.userId,
    required this.movementId,
    this.storagePath,
    this.detectedTotal,
    this.detectedMerchant,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncedAt,
  });

  /// Nombre de la tabla en Supabase.
  static const String table = 'recibos';

  final String id;
  final String? userId;
  final String movementId;
  final String? storagePath;
  final int? detectedTotal;
  final String? detectedMerchant;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? syncedAt;

  /// Lanza [FormatException] si una columna no es válida.
  factory ReceiptDto.fromJson(Map<String, dynamic> json) {
    final row = RemoteJson(json);
    return ReceiptDto(
      id: row.string('id'),
      userId: row.nullableString('usuario_id'),
      movementId: row.string('movimiento_id'),
      storagePath: row.nullableString('ruta_storage'),
      detectedTotal: row.nullableInteger('total_detectado'),
      detectedMerchant: row.nullableString('comercio_detectado'),
      createdAt: row.timestamp('creado_en'),
      updatedAt: row.timestamp('actualizado_en'),
      deletedAt: row.nullableTimestamp('eliminado_en'),
      syncedAt: row.nullableTimestamp('sincronizado_en'),
    );
  }

  /// Fila local lista para enviar. El respaldo de la imagen en Storage llega
  /// en la Fase 6, por eso todavía no hay ruta remota.
  factory ReceiptDto.fromRow(ReceiptRow row) => ReceiptDto(
    id: row.id,
    movementId: row.movementId,
    detectedTotal: row.detectedTotal,
    detectedMerchant: row.detectedMerchant,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
  );

  /// Cuerpo del upsert. Sin `usuario_id` ni `sincronizado_en` (los asigna el
  /// servidor). `ruta_storage` solo se envía si existe, para no borrar un
  /// respaldo hecho desde otro dispositivo.
  Map<String, dynamic> toJson() => {
    'id': id,
    'movimiento_id': movementId,
    if (storagePath != null) 'ruta_storage': storagePath,
    'total_detectado': detectedTotal,
    'comercio_detectado': detectedMerchant,
    'creado_en': timestampToRemote(createdAt),
    'actualizado_en': timestampToRemote(updatedAt),
    'eliminado_en': deletedAt == null ? null : timestampToRemote(deletedAt!),
  };

  /// Fila local con lo recibido del servidor, ya sincronizada. `ruta_local`
  /// queda ausente: un recibo nuevo llega sin imagen y uno existente conserva
  /// la suya al actualizarse.
  ReceiptsCompanion toCompanion() => ReceiptsCompanion(
    id: Value(id),
    movementId: Value(movementId),
    detectedTotal: Value(detectedTotal),
    detectedMerchant: Value(detectedMerchant),
    createdAt: Value(createdAt.toUtc()),
    updatedAt: Value(updatedAt.toUtc()),
    deletedAt: Value(deletedAt?.toUtc()),
    syncStatus: Value(syncStatusSqlValues[SyncStatus.synced]!),
  );
}
