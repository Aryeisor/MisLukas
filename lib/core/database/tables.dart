// Las restricciones CHECK de Drift se escriben refiriéndose a la propia
// columna (`amount.isBiggerThanValue(0)`); el generador no ejecuta el getter.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'sql_converters.dart';

// Tablas locales (docs/06 §6.4). Nombres de tablas y columnas en SQL en
// español, iguales al esquema de Supabase; clases y campos de Dart en inglés.
// La base pertenece a un solo usuario: no guarda usuario_id (se agrega al
// sincronizar en la Fase 5).

/// Marcas de tiempo, borrado lógico y estado de sincronización de las tablas
/// de negocio.
mixin SyncedColumns on Table {
  DateTimeColumn get createdAt => dateTime().named('creado_en')();
  DateTimeColumn get updatedAt => dateTime().named('actualizado_en')();
  DateTimeColumn get deletedAt => dateTime().named('eliminado_en').nullable()();
  TextColumn get syncStatus => text()
      .named('estado_sync')
      .check(syncStatus.isIn(const ['sincronizado', 'pendiente', 'error']))
      .withDefault(const Constant('pendiente'))();
}

@DataClassName('CategoryRow')
class Categories extends Table with SyncedColumns {
  @override
  String get tableName => 'categorias';

  TextColumn get id => text()();
  TextColumn get name => text().named('nombre')();
  TextColumn get type =>
      text().named('tipo').check(type.isIn(const ['gasto', 'ingreso']))();
  TextColumn get icon => text().named('icono').nullable()();
  TextColumn get color => text().named('color').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('MovementRow')
@TableIndex(name: 'idx_movimientos_fecha', columns: {#date})
class Movements extends Table with SyncedColumns {
  @override
  String get tableName => 'movimientos';

  TextColumn get id => text()();
  TextColumn get categoryId =>
      text().named('categoria_id').references(Categories, #id)();
  TextColumn get type =>
      text().named('tipo').check(type.isIn(const ['gasto', 'ingreso']))();
  IntColumn get amount =>
      integer().named('monto').check(amount.isBiggerThanValue(0))();
  TextColumn get date => text().named('fecha').map(const SqlDateConverter())();
  TextColumn get description => text().named('descripcion')();
  TextColumn get note => text().named('nota').nullable()();
  TextColumn get origin =>
      text().named('origen').check(origin.isIn(const ['foto', 'manual']))();
  TextColumn get account =>
      text().named('cuenta').withDefault(const Constant('principal'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Un presupuesto activo por categoría y mes. Los eliminados (borrado lógico)
/// no cuentan, para poder crear otro después.
@DataClassName('BudgetRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_presupuestos_categoria_mes_activo '
  'ON presupuestos (categoria_id, mes) WHERE eliminado_en IS NULL',
)
class Budgets extends Table with SyncedColumns {
  @override
  String get tableName => 'presupuestos';

  TextColumn get id => text()();
  TextColumn get categoryId =>
      text().named('categoria_id').references(Categories, #id)();

  /// Primer día del mes.
  TextColumn get month => text().named('mes').map(const SqlDateConverter())();
  IntColumn get limitAmount =>
      integer().named('monto_limite').check(limitAmount.isBiggerThanValue(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Un recibo activo por movimiento; los eliminados no cuentan.
@DataClassName('ReceiptRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_recibos_movimiento_activo '
  'ON recibos (movimiento_id) WHERE eliminado_en IS NULL',
)
class Receipts extends Table with SyncedColumns {
  @override
  String get tableName => 'recibos';

  TextColumn get id => text()();

  TextColumn get movementId =>
      text().named('movimiento_id').references(Movements, #id)();

  /// Imagen en el almacenamiento interno de la app. Null si el recibo llegó
  /// del servidor y la imagen no está en este dispositivo.
  TextColumn get localPath => text().named('ruta_local').nullable()();
  IntColumn get detectedTotal =>
      integer().named('total_detectado').nullable()();
  TextColumn get detectedMerchant =>
      text().named('comercio_detectado').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Cambios pendientes de enviar al servidor, en orden (docs/06 §6.6.2).
@DataClassName('SyncQueueEntry')
class SyncQueue extends Table {
  @override
  String get tableName => 'cola_sincronizacion';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get targetTable => text().named('tabla')();
  TextColumn get recordId => text().named('registro_id')();
  TextColumn get operation => text()
      .named('operacion')
      .check(operation.isIn(const ['crear', 'actualizar', 'eliminar']))();
  DateTimeColumn get createdAt => dateTime().named('fecha')();
  IntColumn get attempts =>
      integer().named('intentos').withDefault(const Constant(0))();

  /// Momento a partir del cual se puede reintentar un registro que el
  /// servidor rechazó; null si se puede enviar ya (v3).
  DateTimeColumn get nextAttemptAt =>
      dateTime().named('proximo_intento').nullable()();

  /// Código del último rechazo del servidor (por ejemplo, 23514). Solo el
  /// código: nunca el mensaje, que puede incluir datos del usuario (v3).
  TextColumn get lastError => text().named('ultimo_error').nullable()();
}

/// Última sincronización de cada tabla (docs/06 §6.4.3).
@DataClassName('SyncMetadataRow')
class SyncMetadata extends Table {
  @override
  String get tableName => 'metadatos_sync';

  TextColumn get targetTable => text().named('tabla')();
  DateTimeColumn get lastSyncedAt =>
      dateTime().named('ultima_sincronizacion').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {targetTable};
}

/// Ajustes de este dispositivo, como la marca de la bienvenida (v4). No se
/// sincronizan: se borran con el resto de los datos locales.
@DataClassName('LocalSettingRow')
class LocalSettings extends Table {
  @override
  String get tableName => 'ajustes_locales';

  TextColumn get key => text().named('clave')();
  TextColumn get value => text().named('valor')();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
