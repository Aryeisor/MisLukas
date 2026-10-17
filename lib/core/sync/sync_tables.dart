import 'package:drift/drift.dart';

import '../../features/budgets/data/remote/budget_dto.dart';
import '../../features/budgets/data/remote/category_dto.dart';
import '../../features/budgets/domain/entities/default_categories.dart';
import '../../features/movements/data/remote/movement_dto.dart';
import '../../features/movements/data/remote/receipt_dto.dart';
import '../database/app_database.dart';
import '../database/sql_converters.dart';
import 'sync_status.dart';

/// Identidad y marcas de tiempo de un registro, local o remoto.
class SyncRecordInfo {
  const SyncRecordInfo({
    required this.id,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
}

/// Operaciones de sincronización de una tabla, sin tipos genéricos, para
/// recorrer las cuatro tablas en una sola lista.
abstract interface class SyncTableOps {
  /// Nombre de la tabla, igual en SQLite y en Supabase.
  String get name;

  TableInfo<Table, DataClass> table(AppDatabase db);
  GeneratedColumn<String> idColumn(AppDatabase db);
  GeneratedColumn<DateTime> deletedAtColumn(AppDatabase db);

  SyncRecordInfo localInfo(DataClass row);

  /// Cuerpo del upsert (sin usuario_id ni sincronizado_en).
  Map<String, dynamic> toRemote(DataClass row);

  /// Lanza [FormatException] o [ArgumentError] si la fila no es válida.
  Object parse(Map<String, dynamic> json);
  SyncRecordInfo remoteInfo(Object remote);

  /// Fila local con lo recibido, ya sincronizada.
  Insertable<DataClass> toCompanion(Object remote);

  /// Fila local con lo recibido, pero eliminada en [at] y pendiente de
  /// enviar: el registro remoto perdió un choque de "único entre activos".
  Insertable<DataClass> asDeletedCompanion(Object remote, DateTime at);

  /// La fila local ya es igual a la remota y está sincronizada.
  bool sameAs(DataClass local, Object remote);

  /// Registros que nunca se envían (categorías predeterminadas).
  bool isFixedLocal(String id);

  /// Registros remotos que nunca se aplican (categorías predeterminadas).
  bool isFixedRemote(Object remote);

  /// Condición de la llave "única entre los no eliminados" para el registro
  /// remoto, o null si la tabla no tiene: presupuestos (categoría, mes) y
  /// recibos (movimiento).
  Expression<bool>? activeKey(AppDatabase db, Object remote);

  /// La tabla tiene una llave "única entre los no eliminados".
  bool get hasActiveKey;

  /// Valores sueltos por nombre de columna (por ejemplo, solo estado_sync),
  /// con el tipo de fila de la tabla.
  Insertable<DataClass> rawValues(Map<String, Expression<Object>> values);
}

class _SyncTable<R extends DataClass, D extends Object>
    implements SyncTableOps {
  const _SyncTable({
    required this.name,
    required this._tableOf,
    required this._localInfo,
    required this._toRemote,
    required this._parse,
    required this._remoteInfo,
    required this._toCompanion,
    required this._asDeletedCompanion,
    required this._remoteJson,
    this._isFixedLocal,
    this._isFixedRemote,
    this._activeKey,
  });

  @override
  final String name;
  final TableInfo<Table, R> Function(AppDatabase db) _tableOf;
  final SyncRecordInfo Function(R row) _localInfo;
  final Map<String, dynamic> Function(R row) _toRemote;
  final D Function(Map<String, dynamic> json) _parse;
  final SyncRecordInfo Function(D remote) _remoteInfo;
  final Insertable<R> Function(D remote) _toCompanion;
  final Insertable<R> Function(D remote, DateTime at) _asDeletedCompanion;

  /// Cuerpo que se enviaría con los datos remotos: para comparar con la fila
  /// local en el mismo formato.
  final Map<String, dynamic> Function(D remote) _remoteJson;
  final bool Function(String id)? _isFixedLocal;
  final bool Function(D remote)? _isFixedRemote;
  final Expression<bool> Function(AppDatabase db, D remote)? _activeKey;

  @override
  TableInfo<Table, DataClass> table(AppDatabase db) => _tableOf(db);

  @override
  GeneratedColumn<String> idColumn(AppDatabase db) =>
      _tableOf(db).columnsByName['id']! as GeneratedColumn<String>;

  @override
  GeneratedColumn<DateTime> deletedAtColumn(AppDatabase db) =>
      _tableOf(db).columnsByName['eliminado_en']! as GeneratedColumn<DateTime>;

  @override
  SyncRecordInfo localInfo(DataClass row) => _localInfo(row as R);

  @override
  Map<String, dynamic> toRemote(DataClass row) => _toRemote(row as R);

  @override
  Object parse(Map<String, dynamic> json) => _parse(json);

  @override
  SyncRecordInfo remoteInfo(Object remote) => _remoteInfo(remote as D);

  @override
  Insertable<DataClass> toCompanion(Object remote) => _toCompanion(remote as D);

  @override
  Insertable<DataClass> asDeletedCompanion(Object remote, DateTime at) =>
      _asDeletedCompanion(remote as D, at);

  @override
  bool sameAs(DataClass local, Object remote) {
    final row = local as R;
    final status = (row.toJson()['syncStatus'] as String?) ?? '';
    return status == _synced &&
        _sameJson(_toRemote(row), _remoteJson(remote as D));
  }

  @override
  bool isFixedLocal(String id) => _isFixedLocal?.call(id) ?? false;

  @override
  bool isFixedRemote(Object remote) =>
      _isFixedRemote?.call(remote as D) ?? false;

  @override
  bool get hasActiveKey => _activeKey != null;

  @override
  Insertable<DataClass> rawValues(Map<String, Expression<Object>> values) =>
      RawValuesInsertable<R>(values);

  @override
  Expression<bool>? activeKey(AppDatabase db, Object remote) =>
      _activeKey?.call(db, remote as D);
}

final String _synced = syncStatusSqlValues[SyncStatus.synced]!;
final String _pending = syncStatusSqlValues[SyncStatus.pending]!;

SyncRecordInfo _info(String id, DateTime updatedAt, DateTime? deletedAt) =>
    SyncRecordInfo(id: id, updatedAt: updatedAt, deletedAt: deletedAt);

final SyncTableOps categoriesSync = _SyncTable<CategoryRow, CategoryDto>(
  name: CategoryDto.table,
  tableOf: (db) => db.categories,
  localInfo: (r) => _info(r.id, r.updatedAt, r.deletedAt),
  toRemote: (r) => CategoryDto.fromRow(r).toJson(),
  parse: CategoryDto.fromJson,
  remoteInfo: (d) => _info(d.id, d.updatedAt, d.deletedAt),
  remoteJson: (d) => d.toJson(),
  toCompanion: (d) => d.toCompanion(),
  asDeletedCompanion: (d, at) => d.toCompanion().copyWith(
    deletedAt: Value(at.toUtc()),
    updatedAt: Value(at.toUtc()),
    syncStatus: Value(_pending),
  ),
  // Las predeterminadas son fijas en la app y en el servidor (docs/06 §6.4.2).
  isFixedLocal: (id) => DefaultCategory.fromId(id) != null,
  isFixedRemote: (d) => d.isDefault || DefaultCategory.fromId(d.id) != null,
);

final SyncTableOps movementsSync = _SyncTable<MovementRow, MovementDto>(
  name: MovementDto.table,
  tableOf: (db) => db.movements,
  localInfo: (r) => _info(r.id, r.updatedAt, r.deletedAt),
  toRemote: (r) => MovementDto.fromRow(r).toJson(),
  parse: MovementDto.fromJson,
  remoteInfo: (d) => _info(d.id, d.updatedAt, d.deletedAt),
  remoteJson: (d) => d.toJson(),
  toCompanion: (d) => d.toCompanion(),
  asDeletedCompanion: (d, at) => d.toCompanion().copyWith(
    deletedAt: Value(at.toUtc()),
    updatedAt: Value(at.toUtc()),
    syncStatus: Value(_pending),
  ),
);

final SyncTableOps budgetsSync = _SyncTable<BudgetRow, BudgetDto>(
  name: BudgetDto.table,
  tableOf: (db) => db.budgets,
  localInfo: (r) => _info(r.id, r.updatedAt, r.deletedAt),
  toRemote: (r) => BudgetDto.fromRow(r).toJson(),
  parse: BudgetDto.fromJson,
  remoteInfo: (d) => _info(d.id, d.updatedAt, d.deletedAt),
  remoteJson: (d) => d.toJson(),
  toCompanion: (d) => d.toCompanion(),
  asDeletedCompanion: (d, at) => d.toCompanion().copyWith(
    deletedAt: Value(at.toUtc()),
    updatedAt: Value(at.toUtc()),
    syncStatus: Value(_pending),
  ),
  activeKey: (db, d) =>
      db.budgets.categoryId.equals(d.categoryId) &
      db.budgets.month.equalsValue(d.month),
);

final SyncTableOps receiptsSync = _SyncTable<ReceiptRow, ReceiptDto>(
  name: ReceiptDto.table,
  tableOf: (db) => db.receipts,
  localInfo: (r) => _info(r.id, r.updatedAt, r.deletedAt),
  toRemote: (r) => ReceiptDto.fromRow(r).toJson(),
  parse: ReceiptDto.fromJson,
  remoteInfo: (d) => _info(d.id, d.updatedAt, d.deletedAt),
  // ruta_storage no existe en la base local: se comparan los demás datos.
  remoteJson: (d) => d.toJson()..remove('ruta_storage'),
  // Sin ruta_local: nunca se sobrescribe desde el servidor.
  toCompanion: (d) => d.toCompanion(),
  asDeletedCompanion: (d, at) => d.toCompanion().copyWith(
    deletedAt: Value(at.toUtc()),
    updatedAt: Value(at.toUtc()),
    syncStatus: Value(_pending),
  ),
  activeKey: (db, d) => db.receipts.movementId.equals(d.movementId),
);

/// Tablas en el orden de sus llaves foráneas: así el servidor (al enviar) y
/// la base local (al recibir) siempre tienen la fila referida.
final List<SyncTableOps> syncTables = [
  categoriesSync,
  movementsSync,
  budgetsSync,
  receiptsSync,
];

bool _sameJson(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
  }
  return true;
}
