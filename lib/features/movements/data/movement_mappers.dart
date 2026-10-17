import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/sql_converters.dart';
import '../../../core/sync/sync_status.dart';
import '../domain/entities/movement.dart';
import '../domain/entities/receipt.dart';

// Conversión entre filas de Drift y entidades de dominio de movimientos.

String movementTypeToSql(MovementType type) => switch (type) {
  MovementType.expense => 'gasto',
  MovementType.income => 'ingreso',
};

MovementType movementTypeFromSql(String value) => switch (value) {
  'gasto' => MovementType.expense,
  'ingreso' => MovementType.income,
  _ => throw ArgumentError.value(value, 'tipo'),
};

String movementOriginToSql(MovementOrigin origin) => switch (origin) {
  MovementOrigin.photo => 'foto',
  MovementOrigin.manual => 'manual',
};

MovementOrigin movementOriginFromSql(String value) => switch (value) {
  'foto' => MovementOrigin.photo,
  'manual' => MovementOrigin.manual,
  _ => throw ArgumentError.value(value, 'origen'),
};

final String _pending = syncStatusSqlValues[SyncStatus.pending]!;

extension MovementRowMapper on MovementRow {
  Movement toEntity() => Movement(
    id: id,
    type: movementTypeFromSql(type),
    amount: amount,
    date: date,
    categoryId: categoryId,
    description: description,
    note: note,
    origin: movementOriginFromSql(origin),
    account: account,
    createdAt: createdAt.toLocal(),
    updatedAt: updatedAt.toLocal(),
    deletedAt: deletedAt?.toLocal(),
    syncStatus: syncStatusFromSql(syncStatus),
  );
}

extension MovementToCompanion on Movement {
  /// Fila para insertar o actualizar. Toda escritura local queda pendiente de
  /// sincronizar, sin importar el estado que traiga la entidad.
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
    syncStatus: Value(_pending),
  );
}

extension ReceiptRowMapper on ReceiptRow {
  Receipt toEntity() => Receipt(
    id: id,
    movementId: movementId,
    localPath: localPath,
    detectedTotal: detectedTotal,
    detectedMerchant: detectedMerchant,
  );
}

extension ReceiptToCompanion on Receipt {
  ReceiptsCompanion toCompanion({required DateTime at}) =>
      ReceiptsCompanion.insert(
        id: id,
        movementId: movementId,
        localPath: Value(localPath),
        detectedTotal: Value(detectedTotal),
        detectedMerchant: Value(detectedMerchant),
        createdAt: at.toUtc(),
        updatedAt: at.toUtc(),
        syncStatus: Value(_pending),
      );
}
