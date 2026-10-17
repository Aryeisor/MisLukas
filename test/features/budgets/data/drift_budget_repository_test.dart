import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/features/budgets/data/drift_budget_repository.dart';
import 'package:mislukas/features/budgets/data/drift_category_repository.dart';
import 'package:mislukas/features/budgets/domain/entities/budget.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftBudgetRepository budgets;

  setUp(() {
    db = openTestDatabase();
    budgets = DriftBudgetRepository(db);
  });
  tearDown(() => db.close());

  Budget mercado(int limit, {String id = 'b1'}) => Budget(
    id: id,
    categoryId: DefaultCategory.mercado.id,
    month: DateTime(2026, 9),
    limitAmount: limit,
  );

  group('categorías', () {
    test('las predeterminadas existen con su UUID, clave y tipo', () async {
      final categories = DriftCategoryRepository(db);
      final all = await categories.getAll();
      expect(all, hasLength(7));
      expect(all.toSet(), {
        for (final c in DefaultCategory.values) c.toCategory(),
      });
      expect(
        await categories.findById(DefaultCategory.restaurantes.id),
        DefaultCategory.restaurantes.toCategory(),
      );
      expect(await categories.findById('no-existe'), isNull);
      expect((await categories.watchAll().first).first.name, 'Ingreso');
    });
  });

  test('guardar crea el presupuesto pendiente y lo encola', () async {
    final saved = await budgets.save(mercado(1150000), at: testToday);
    expect(saved, mercado(1150000));
    expect(await budgets.getForMonth(DateTime(2026, 9)), [saved]);

    final row = await db.select(db.budgets).getSingle();
    expect(row.syncStatus, 'pendiente');
    final entry = await db.select(db.syncQueue).getSingle();
    expect(entry.targetTable, 'presupuestos');
    expect(entry.operation, 'crear');
  });

  test(
    'guardar de nuevo la misma categoría y mes actualiza sin duplicar',
    () async {
      await budgets.save(mercado(1000), at: testToday);
      final saved = await budgets.save(
        mercado(2000, id: 'otro'),
        at: testToday,
      );

      expect(saved.id, 'b1');
      expect(saved.limitAmount, 2000);
      expect(await db.select(db.budgets).get(), hasLength(1));
      expect((await db.select(db.syncQueue).get()).map((e) => e.operation), [
        'crear',
        'actualizar',
      ]);
    },
  );

  test('la restricción única rechaza presupuestos duplicados', () async {
    await budgets.save(mercado(1000), at: testToday);
    await expectLater(
      db
          .into(db.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: 'b2',
              categoryId: DefaultCategory.mercado.id,
              month: DateTime(2026, 9),
              limitAmount: 5,
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          ),
      throwsA(anything),
    );
  });

  test('CHECK rechaza monto_limite 0 o negativo', () async {
    for (final limit in [0, -1]) {
      await expectLater(
        budgets.save(mercado(limit), at: testToday),
        throwsA(anything),
      );
    }
    expect(await db.select(db.budgets).get(), isEmpty);
    expect(await db.select(db.syncQueue).get(), isEmpty);
  });

  test('watchForMonth emite al guardar', () async {
    final expectation = expectLater(
      budgets.watchForMonth(DateTime(2026, 9)),
      emitsInOrder([
        isEmpty,
        [mercado(1000)],
      ]),
    );
    await pumpEventQueue();
    await budgets.save(mercado(1000), at: testToday);
    await expectation;
  });

  test(
    'un presupuesto eliminado no revive: se crea otro con id nuevo',
    () async {
      await budgets.save(mercado(1000), at: testToday);
      final deletedAt = DateTime.utc(2026, 9, 23);
      await (db.update(db.budgets)..where((t) => t.id.equals('b1'))).write(
        BudgetsCompanion(deletedAt: Value(deletedAt)),
      );
      expect(await budgets.getForMonth(DateTime(2026, 9)), isEmpty);

      await budgets.save(mercado(3000, id: 'nuevo'), at: testToday);
      final active = await budgets.getForMonth(DateTime(2026, 9));
      expect(active.single.id, 'nuevo');
      expect(active.single.limitAmount, 3000);

      final old = await (db.select(
        db.budgets,
      )..where((t) => t.id.equals('b1'))).getSingle();
      expect(old.deletedAt, deletedAt);
    },
  );
}
