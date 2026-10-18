import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';

import '../../helpers/test_database.dart';

/// Esquema v1 tal como lo creaba Drift en la Fase 4 (sqlite_master).
const List<String> _v1Schema = [
  '''CREATE TABLE "categorias" ("creado_en" TEXT NOT NULL, "actualizado_en" TEXT NOT NULL, "eliminado_en" TEXT NULL, "estado_sync" TEXT NOT NULL DEFAULT 'pendiente' CHECK("estado_sync" IN ('sincronizado', 'pendiente', 'error')), "id" TEXT NOT NULL, "nombre" TEXT NOT NULL, "tipo" TEXT NOT NULL CHECK("tipo" IN ('gasto', 'ingreso')), "icono" TEXT NULL, "color" TEXT NULL, PRIMARY KEY ("id"))''',
  '''CREATE TABLE "movimientos" ("creado_en" TEXT NOT NULL, "actualizado_en" TEXT NOT NULL, "eliminado_en" TEXT NULL, "estado_sync" TEXT NOT NULL DEFAULT 'pendiente' CHECK("estado_sync" IN ('sincronizado', 'pendiente', 'error')), "id" TEXT NOT NULL, "categoria_id" TEXT NOT NULL REFERENCES categorias (id), "tipo" TEXT NOT NULL CHECK("tipo" IN ('gasto', 'ingreso')), "monto" INTEGER NOT NULL CHECK("monto" > 0), "fecha" TEXT NOT NULL, "descripcion" TEXT NOT NULL, "nota" TEXT NULL, "origen" TEXT NOT NULL CHECK("origen" IN ('foto', 'manual')), "cuenta" TEXT NOT NULL DEFAULT 'principal', PRIMARY KEY ("id"))''',
  '''CREATE TABLE "presupuestos" ("creado_en" TEXT NOT NULL, "actualizado_en" TEXT NOT NULL, "eliminado_en" TEXT NULL, "estado_sync" TEXT NOT NULL DEFAULT 'pendiente' CHECK("estado_sync" IN ('sincronizado', 'pendiente', 'error')), "id" TEXT NOT NULL, "categoria_id" TEXT NOT NULL REFERENCES categorias (id), "mes" TEXT NOT NULL, "monto_limite" INTEGER NOT NULL CHECK("monto_limite" > 0), PRIMARY KEY ("id"), UNIQUE ("categoria_id", "mes"))''',
  '''CREATE TABLE "recibos" ("creado_en" TEXT NOT NULL, "actualizado_en" TEXT NOT NULL, "eliminado_en" TEXT NULL, "estado_sync" TEXT NOT NULL DEFAULT 'pendiente' CHECK("estado_sync" IN ('sincronizado', 'pendiente', 'error')), "id" TEXT NOT NULL, "movimiento_id" TEXT NOT NULL UNIQUE REFERENCES movimientos (id), "ruta_local" TEXT NOT NULL, "total_detectado" INTEGER NULL, "comercio_detectado" TEXT NULL, PRIMARY KEY ("id"))''',
  '''CREATE TABLE "cola_sincronizacion" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "tabla" TEXT NOT NULL, "registro_id" TEXT NOT NULL, "operacion" TEXT NOT NULL CHECK("operacion" IN ('crear', 'actualizar', 'eliminar')), "fecha" TEXT NOT NULL, "intentos" INTEGER NOT NULL DEFAULT 0)''',
  '''CREATE TABLE "metadatos_sync" ("tabla" TEXT NOT NULL, "ultima_sincronizacion" TEXT NULL, PRIMARY KEY ("tabla"))''',
  'CREATE INDEX idx_movimientos_fecha ON movimientos (fecha)',
];

const String _at = '2026-09-22T14:30:05.000Z';

/// Base en memoria con el esquema v1 y algunos datos, que Drift migra al
/// abrirla.
AppDatabase openV1Database() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    NativeDatabase.memory(
      setup: (raw) {
        for (final statement in _v1Schema) {
          raw.execute(statement);
        }
        raw.execute(
          'INSERT INTO categorias (id, nombre, tipo, creado_en, actualizado_en) '
          'VALUES (?, ?, ?, ?, ?)',
          [DefaultCategory.mercado.id, 'Mercado', 'gasto', _at, _at],
        );
        raw.execute(
          'INSERT INTO movimientos (id, categoria_id, tipo, monto, fecha, '
          'descripcion, origen, creado_en, actualizado_en) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            'm1',
            DefaultCategory.mercado.id,
            'gasto',
            87400,
            '2026-09-22',
            'Éxito',
            'foto',
            _at,
            _at,
          ],
        );
        raw.execute(
          'INSERT INTO presupuestos (id, categoria_id, mes, monto_limite, '
          'creado_en, actualizado_en) VALUES (?, ?, ?, ?, ?, ?)',
          ['b1', DefaultCategory.mercado.id, '2026-09-01', 800000, _at, _at],
        );
        raw.execute(
          'INSERT INTO recibos (id, movimiento_id, ruta_local, total_detectado, '
          'creado_en, actualizado_en) VALUES (?, ?, ?, ?, ?, ?)',
          ['r1', 'm1', 'recibos/r1.jpg', 87400, _at, _at],
        );
        raw.execute(
          'INSERT INTO cola_sincronizacion (tabla, registro_id, operacion, '
          'fecha, intentos) VALUES (?, ?, ?, ?, ?)',
          ['movimientos', 'm1', 'crear', _at, 0],
        );
        raw.execute('PRAGMA user_version = 1');
      },
    ),
  );
}

/// Definición SQL de las tablas e índices afectados por la v2 a la v5.
Future<Map<String, String>> schemaOf(AppDatabase db) async {
  final rows = await db
      .customSelect(
        'SELECT name, sql FROM sqlite_master '
        'WHERE tbl_name IN (?, ?, ?, ?, ?) AND sql IS NOT NULL',
        variables: [
          Variable.withString('presupuestos'),
          Variable.withString('recibos'),
          Variable.withString('cola_sincronizacion'),
          Variable.withString('ajustes_locales'),
          Variable.withString('alertas_enviadas'),
        ],
      )
      .get();
  return {for (final r in rows) r.read<String>('name'): r.read<String>('sql')};
}

void main() {
  test('v1 → v5 conserva los datos', () async {
    final db = openV1Database();
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 5);

    final budget = await db.select(db.budgets).getSingle();
    expect(budget.limitAmount, 800000);
    expect(budget.month, DateTime(2026, 9));

    final receipt = await db.select(db.receipts).getSingle();
    expect(receipt.localPath, 'recibos/r1.jpg');
    expect(receipt.movementId, 'm1');
    expect(receipt.createdAt, DateTime.utc(2026, 9, 22, 14, 30, 5));

    // v3: la cola conserva sus entradas, sin próximo intento ni error.
    final entry = await db.select(db.syncQueue).getSingle();
    expect(entry.recordId, 'm1');
    expect(entry.nextAttemptAt, isNull);
    expect(entry.lastError, isNull);

    // v4: ajustes del dispositivo, vacíos (la bienvenida se decide después).
    expect(await db.select(db.localSettings).get(), isEmpty);
    // v5: alertas de presupuesto registradas, vacía.
    expect(await db.select(db.sentBudgetAlerts).get(), isEmpty);
  });

  test('v4 → v5 agrega alertas_enviadas y conserva los datos', () async {
    final directory = await Directory.systemTemp.createTemp('mislukas_v4_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/v4.sqlite');

    // Una base v4: la actual sin la tabla nueva, con un ajuste guardado.
    final v4 = AppDatabase(NativeDatabase(file));
    await v4
        .into(v4.localSettings)
        .insert(LocalSettingsCompanion.insert(key: 'bienvenida', value: 'x'));
    await v4.customStatement('DROP TABLE alertas_enviadas');
    await v4.customStatement('PRAGMA user_version = 4');
    await v4.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 5);
    expect((await db.select(db.localSettings).getSingle()).value, 'x');
    await db
        .into(db.sentBudgetAlerts)
        .insert(
          SentBudgetAlertsCompanion.insert(
            categoryId: DefaultCategory.mercado.id,
            month: DateTime(2026, 9),
            threshold: 75,
            sentAt: DateTime.utc(2026, 9, 22),
          ),
        );
    expect(await db.select(db.sentBudgetAlerts).get(), hasLength(1));

    final fresh = openTestDatabase();
    addTearDown(fresh.close);
    expect(await schemaOf(db), await schemaOf(fresh));
  });

  test('el esquema migrado es igual al de una instalación nueva', () async {
    final migrated = openV1Database();
    final fresh = openTestDatabase();
    addTearDown(migrated.close);
    addTearDown(fresh.close);

    expect(await schemaOf(migrated), await schemaOf(fresh));
  });

  for (final (name, open) in [
    ('instalación nueva', openTestDatabase),
    ('base migrada', openV1Database),
  ]) {
    group(name, () {
      late AppDatabase db;
      final at = DateTime.utc(2026, 9, 22);

      setUp(() async {
        db = open();
        await db
            .into(db.movements)
            .insertOnConflictUpdate(
              MovementsCompanion.insert(
                id: 'm1',
                categoryId: DefaultCategory.mercado.id,
                type: 'gasto',
                amount: 87400,
                date: DateTime(2026, 9, 22),
                description: 'Éxito',
                origin: 'foto',
                createdAt: at,
                updatedAt: at,
              ),
            );
        await db.delete(db.budgets).go();
        await db.delete(db.receipts).go();
      });
      tearDown(() => db.close());

      BudgetsCompanion budget(String id) => BudgetsCompanion.insert(
        id: id,
        categoryId: DefaultCategory.mercado.id,
        month: DateTime(2026, 9),
        limitAmount: 800000,
        createdAt: at,
        updatedAt: at,
      );

      ReceiptsCompanion receipt(String id) => ReceiptsCompanion.insert(
        id: id,
        movementId: 'm1',
        createdAt: at,
        updatedAt: at,
      );

      test('un presupuesto se puede recrear tras el borrado lógico', () async {
        await db.into(db.budgets).insert(budget('b1'));
        await expectLater(
          db.into(db.budgets).insert(budget('b2')),
          throwsA(anything),
        );

        await (db.update(db.budgets)..where((t) => t.id.equals('b1'))).write(
          BudgetsCompanion(deletedAt: Value(at)),
        );
        await db.into(db.budgets).insert(budget('b3'));
        expect(await db.select(db.budgets).get(), hasLength(2));
      });

      test('un recibo se puede recrear tras el borrado lógico', () async {
        await db.into(db.receipts).insert(receipt('r1'));
        await expectLater(
          db.into(db.receipts).insert(receipt('r2')),
          throwsA(anything),
        );

        await (db.update(db.receipts)..where((t) => t.id.equals('r1'))).write(
          ReceiptsCompanion(deletedAt: Value(at)),
        );
        await db.into(db.receipts).insert(receipt('r3'));

        final rows = await db.select(db.receipts).get();
        expect(rows, hasLength(2));
        // Sin ruta local: el recibo puede llegar del servidor sin imagen.
        expect(rows.last.localPath, isNull);
      });
    });
  }
}
