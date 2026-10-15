import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/utils/clock.dart';
import 'package:mislukas/features/budgets/data/drift_budget_repository.dart';
import 'package:mislukas/features/budgets/domain/entities/budget_alert.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/data/drift_movement_repository.dart';
import 'package:mislukas/features/movements/domain/entities/month_summary.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';
import 'package:mislukas/features/reports/domain/entities/category_spending.dart';
import 'package:mislukas/features/simulator/domain/get_savings_average.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftMovementRepository movements;

  setUp(() {
    db = openTestDatabase();
    movements = DriftMovementRepository(db);
  });
  tearDown(() => db.close());

  Future<List<Movement>> monthOf(DateTime month) =>
      movements.getBetween(month, nextMonthStart(month));

  Map<DefaultCategory, int> byCategory(List<Movement> list) => {
    for (final entry in expensesByCategory(list).entries)
      DefaultCategory.fromId(entry.key)!: entry.value,
  };

  group('con el reloj en el 22/09/2026', () {
    setUp(() => testDemoSeed(db).load());

    test('septiembre: gastos por categoría e ingresos de la Fase 3', () async {
      final september = await monthOf(DateTime(2026, 9));
      final summary = summarizeMonth(
        month: DateTime(2026, 9),
        movements: september,
      );

      expect(byCategory(september), phase3SeptemberExpenses);
      expect(summary.expenses, 2375680);
      expect(summary.income, 4250000);
      expect(summary.available, 1874320);
    });

    test('septiembre incluye los movimientos listados en la Fase 3', () async {
      final september = await monthOf(DateTime(2026, 9));
      String describe(Movement m) =>
          '${m.description} ${m.amount} ${m.date.day}';

      expect(
        september.map(describe),
        containsAll([
          'Éxito 87400 22',
          'TransMilenio 5600 21',
          'Salario 3800000 1',
          'Juan Valdez 18500 1',
          'Freelance 450000 1',
        ]),
      );
      // Los demás son anteriores a "ayer".
      final others = september.skip(2);
      expect(others.every((m) => m.date.day < 21), isTrue);
    });

    test('agosto: ingresos 2.615.600 y gastos 2.195.600', () async {
      final august = await monthOf(DateTime(2026, 8));
      final summary = summarizeMonth(
        month: DateTime(2026, 8),
        movements: august,
      );

      expect(byCategory(august), phase3AugustExpenses);
      expect(summary.income, 2615600);
      expect(summary.expenses, 2195600);
    });

    test('junio y julio: ingresos 4.250.000 y gastos 3.830.000', () async {
      for (final month in [DateTime(2026, 6), DateTime(2026, 7)]) {
        final summary = summarizeMonth(
          month: month,
          movements: await monthOf(month),
        );
        expect(summary.income, 4250000, reason: '$month');
        expect(summary.expenses, 3830000, reason: '$month');
      }
    });

    test('ahorro promedio de junio a agosto: 420.000', () async {
      final average = await GetSavingsAverage(
        movements: movements,
        clock: testClock,
      ).call();

      expect(average, isA<SavingsAverageResult>());
      final result = average as SavingsAverageResult;
      expect(result.amount, 420000);
      expect(result.from, DateTime(2026, 6));
      expect(result.to, DateTime(2026, 8));
    });

    test('presupuesto de Mercado 1.150.000 al 78%', () async {
      final budgets = await DriftBudgetRepository(db)
          .getForMonth(DateTime(2026, 9));
      expect(budgets, hasLength(1));
      expect(budgets.single.categoryId, DefaultCategory.mercado.id);
      expect(budgets.single.limitAmount, 1150000);

      final alerts = evaluateBudgetAlerts(
        budgets: budgets,
        movements: await monthOf(DateTime(2026, 9)),
      );
      expect(alerts.single.percent, 78);
      expect(alerts.single.remaining, 253000);
    });

    test('todo pasa por la cola de sincronización', () async {
      final queue = await db.select(db.syncQueue).get();
      final count = (await db.select(db.movements).get()).length;
      expect(
        queue.where((e) => e.targetTable == 'movimientos'),
        hasLength(count),
      );
      expect(queue.where((e) => e.targetTable == 'presupuestos'), hasLength(1));
      expect(queue.every((e) => e.operation == 'crear'), isTrue);
    });

    test('cargar dos veces no duplica', () async {
      final before = (await db.select(db.movements).get()).length;
      await testDemoSeed(db).load();
      expect(await db.select(db.movements).get(), hasLength(before));
      expect(await db.select(db.budgets).get(), hasLength(1));
    });

    test('clearAll borra todo y conserva las categorías', () async {
      await testDemoSeed(db).clearAll();

      expect(await db.select(db.movements).get(), isEmpty);
      expect(await db.select(db.budgets).get(), isEmpty);
      expect(await db.select(db.receipts).get(), isEmpty);
      expect(await db.select(db.syncQueue).get(), isEmpty);
      expect(await db.select(db.categories).get(), hasLength(7));
    });
  });

  test(
    'fechas relativas: el día 1 "hoy" y "ayer" quedan en el día 1',
    () async {
      final clock = FixedClock(DateTime(2027, 3, 1, 8));
      await testDemoSeed(db, clock: clock).load();

      final march = await monthOf(DateTime(2027, 3));
      expect(march.every((m) => m.date == DateTime(2027, 3, 1)), isTrue);
      final summary = summarizeMonth(
        month: DateTime(2027, 3),
        movements: march,
      );
      expect(summary.expenses, 2375680);
      expect(summary.income, 4250000);

      // El mes anterior es febrero y los completos, noviembre a enero.
      final february = summarizeMonth(
        month: DateTime(2027, 2),
        movements: await monthOf(DateTime(2027, 2)),
      );
      expect(february.expenses, 2195600);
      final average =
          await GetSavingsAverage(movements: movements, clock: clock).call()
              as SavingsAverageResult;
      expect(average.amount, 420000);
      expect(average.from, DateTime(2026, 12));
      expect(average.to, DateTime(2027, 2));
    },
  );

  test('fechas relativas: ningún movimiento queda en el futuro', () async {
    final clock = FixedClock(DateTime(2026, 9, 5, 8));
    await testDemoSeed(db, clock: clock).load();

    final all = await movements.getBetween(DateTime(2000), DateTime(2100));
    expect(all.every((m) => !m.date.isAfter(DateTime(2026, 9, 5))), isTrue);
    final september = await monthOf(DateTime(2026, 9));
    expect(
      september
          .where((m) => m.date == DateTime(2026, 9, 5))
          .map((m) => m.description),
      ['Éxito'],
    );
    expect(
      september
          .where((m) => m.date == DateTime(2026, 9, 4))
          .map((m) => m.description),
      ['TransMilenio'],
    );
  });
}
