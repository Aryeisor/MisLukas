import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  test('tablas con los nombres en español de docs/06 §6.4', () async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    expect(rows.map((r) => r.read<String>('name')).toSet(), {
      'categorias',
      'movimientos',
      'presupuestos',
      'recibos',
      'cola_sincronizacion',
      'metadatos_sync',
      'ajustes_locales',
      'alertas_enviadas',
    });
  });

  test('columnas de movimientos en español', () async {
    final columns = await db
        .customSelect(
          'SELECT name FROM pragma_table_info(?)',
          variables: [Variable.withString('movimientos')],
        )
        .get();
    expect(columns.map((c) => c.read<String>('name')).toSet(), {
      'id',
      'categoria_id',
      'tipo',
      'monto',
      'fecha',
      'descripcion',
      'nota',
      'origen',
      'cuenta',
      'creado_en',
      'actualizado_en',
      'eliminado_en',
      'estado_sync',
    });
  });

  test(
    'categorías predeterminadas con sus UUID fijos, sincronizadas',
    () async {
      final rows = await db.select(db.categories).get();
      expect(
        {for (final r in rows) r.id: r.name},
        {for (final c in DefaultCategory.values) c.id: c.displayName},
      );
      expect(rows.every((r) => r.syncStatus == 'sincronizado'), isTrue);
      expect(
        rows.singleWhere((r) => r.id == DefaultCategory.ingreso.id).type,
        'ingreso',
      );
      // No entran a la cola: el servidor ya las tiene.
      expect(await db.select(db.syncQueue).get(), isEmpty);
    },
  );

  test('llaves foráneas activas', () async {
    final result = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(result.read<int>('foreign_keys'), 1);
  });

  test(
    'las restricciones CHECK rechazan tipo, origen y estado inválidos',
    () async {
      final now = DateTime.utc(2026, 9, 22);
      Future<void> insert({String tipo = 'gasto', String origen = 'manual'}) {
        return db
            .into(db.movements)
            .insert(
              MovementsCompanion.insert(
                id: 'x-$tipo-$origen',
                categoryId: DefaultCategory.mercado.id,
                type: tipo,
                amount: 100,
                date: DateTime(2026, 9, 22),
                description: 'x',
                origin: origen,
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      await expectLater(insert(tipo: 'otro'), throwsA(anything));
      await expectLater(insert(origen: 'correo'), throwsA(anything));
      await insert();
      final row = await db.select(db.movements).getSingle();
      expect(row.account, 'principal');
      expect(row.syncStatus, 'pendiente');
    },
  );

  test('un movimiento con categoría inexistente se rechaza', () async {
    final now = DateTime.utc(2026, 9, 22);
    await expectLater(
      db
          .into(db.movements)
          .insert(
            MovementsCompanion.insert(
              id: 'x',
              categoryId: 'no-existe',
              type: 'gasto',
              amount: 100,
              date: DateTime(2026, 9, 22),
              description: 'x',
              origin: 'manual',
              createdAt: now,
              updatedAt: now,
            ),
          ),
      throwsA(anything),
    );
  });

  test('las fechas se guardan como texto AAAA-MM-DD', () async {
    final now = DateTime.utc(2026, 9, 22);
    await db
        .into(db.movements)
        .insert(
          MovementsCompanion.insert(
            id: 'x',
            categoryId: DefaultCategory.mercado.id,
            type: 'gasto',
            amount: 100,
            date: DateTime(2026, 9, 2),
            description: 'x',
            origin: 'manual',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final raw = await db
        .customSelect('SELECT fecha, typeof(monto) AS t FROM movimientos')
        .getSingle();
    expect(raw.read<String>('fecha'), '2026-09-02');
    expect(raw.read<String>('t'), 'integer');
  });
}
