import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/sync/sync_operation.dart';
import 'package:mislukas/features/budgets/data/drift_budget_repository.dart';
import 'package:mislukas/features/budgets/domain/entities/budget.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftBudgetRepository repository;
  late SequentialIdGenerator ids;

  final september = DateTime(2026, 9);
  final october = DateTime(2026, 10);
  final octoberFirst = DateTime(2026, 10, 1, 8);

  setUp(() {
    db = openTestDatabase();
    repository = DriftBudgetRepository(db);
    ids = SequentialIdGenerator();
  });

  tearDown(() => db.close());

  Future<Budget> save(DefaultCategory category, int limit, DateTime month) =>
      repository.save(
        Budget(
          id: ids.newId(),
          categoryId: category.id,
          month: month,
          limitAmount: limit,
        ),
        at: testToday,
      );

  Future<List<Budget>> carryOver() => repository.carryOver(
    month: october,
    at: octoberFirst,
    newId: () => 'copia-${ids.newId()}',
  );

  Future<List<BudgetRow>> rowsOf(DateTime month) =>
      (db.select(db.budgets)..where((t) => t.month.equalsValue(month))).get();

  group('remove', () {
    test('deja una lápida pendiente y una entrada delete en la cola', () async {
      final budget = await save(DefaultCategory.mercado, 500000, september);

      await repository.remove(budget.id, at: testToday);

      expect(await repository.findById(budget.id), isNull);
      expect(await repository.getForMonth(september), isEmpty);
      final row = (await rowsOf(september)).single;
      expect(row.deletedAt, isNotNull);
      expect(row.syncStatus, 'pendiente');
      final queue = await db.select(db.syncQueue).get();
      expect(queue.last.recordId, budget.id);
      expect(queue.last.operation, SyncOperation.delete.sqlValue);
    });

    test('uno ya quitado no se puede quitar otra vez', () async {
      final budget = await save(DefaultCategory.mercado, 500000, september);
      await repository.remove(budget.id, at: testToday);
      final queueBefore = await db.select(db.syncQueue).get();

      await expectLater(
        repository.remove(budget.id, at: testToday),
        throwsStateError,
      );
      // La entrada de la cola se revierte con la transacción.
      expect(
        await db.select(db.syncQueue).get(),
        hasLength(queueBefore.length),
      );
    });
  });

  group('carryOver', () {
    test(
      'copia los del mes anterior con ids nuevos y los mismos límites',
      () async {
        final market = await save(DefaultCategory.mercado, 500000, september);
        await save(DefaultCategory.transporte, 200000, september);

        final copies = await carryOver();

        expect(copies, hasLength(2));
        expect(copies.map((b) => b.month).toSet(), {october});
        expect(copies.map((b) => b.id), everyElement(startsWith('copia-')));
        expect(copies.map((b) => b.id), isNot(contains(market.id)));
        final active = await repository.getForMonth(october);
        expect(
          {for (final b in active) b.categoryId: b.limitAmount},
          {
            DefaultCategory.mercado.id: 500000,
            DefaultCategory.transporte.id: 200000,
          },
        );
        // Septiembre no cambia.
        expect(await repository.getForMonth(september), hasLength(2));
        // Cada copia queda pendiente y en la cola para sincronizarse.
        final rows = await rowsOf(october);
        expect(rows.map((r) => r.syncStatus), everyElement('pendiente'));
        final queue = await db.select(db.syncQueue).get();
        for (final copy in copies) {
          expect(
            queue.where(
              (e) =>
                  e.recordId == copy.id &&
                  e.operation == SyncOperation.create.sqlValue,
            ),
            hasLength(1),
          );
        }
      },
    );

    test('es idempotente: la segunda vez no copia nada', () async {
      await save(DefaultCategory.mercado, 500000, september);

      expect(await carryOver(), hasLength(1));
      expect(await carryOver(), isEmpty);
      expect(await rowsOf(october), hasLength(1));
    });

    test('un presupuesto quitado en el mes no vuelve', () async {
      await save(DefaultCategory.mercado, 500000, september);
      await save(DefaultCategory.ocio, 100000, september);
      final copies = await carryOver();
      final ocio = copies.firstWhere(
        (b) => b.categoryId == DefaultCategory.ocio.id,
      );

      await repository.remove(ocio.id, at: octoberFirst);
      expect(await carryOver(), isEmpty);

      final active = await repository.getForMonth(october);
      expect(active.single.categoryId, DefaultCategory.mercado.id);
    });

    test('si quitó todos en el mes, el siguiente no copia nada', () async {
      final market = await save(DefaultCategory.mercado, 500000, september);
      await repository.remove(market.id, at: testToday);

      expect(await carryOver(), isEmpty);
      expect(await rowsOf(october), isEmpty);
    });

    test('salta los meses sin presupuestos', () async {
      await save(DefaultCategory.servicios, 150000, DateTime(2026, 7));

      final copies = await carryOver();

      expect(copies.single.categoryId, DefaultCategory.servicios.id);
      expect(copies.single.limitAmount, 150000);
      expect(copies.single.month, october);
    });

    test('sin presupuestos anteriores no hace nada', () async {
      expect(await carryOver(), isEmpty);
      // Un presupuesto de un mes posterior no es origen.
      await save(DefaultCategory.mercado, 500000, DateTime(2026, 11));
      expect(await carryOver(), isEmpty);
    });

    test('si el mes ya tiene presupuestos, no copia', () async {
      await save(DefaultCategory.mercado, 500000, september);
      await save(DefaultCategory.ocio, 90000, october);

      expect(await carryOver(), isEmpty);
      expect(
        (await repository.getForMonth(october)).single.categoryId,
        DefaultCategory.ocio.id,
      );
    });

    test('un presupuesto eliminado ya no revive al guardar de nuevo', () async {
      final market = await save(DefaultCategory.mercado, 500000, september);
      await repository.remove(market.id, at: testToday);

      final again = await save(DefaultCategory.mercado, 700000, september);

      expect(again.id, isNot(market.id));
      expect(
        (await repository.getForMonth(september)).single.limitAmount,
        700000,
      );
    });
  });
}
