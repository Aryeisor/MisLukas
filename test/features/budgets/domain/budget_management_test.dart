import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/errors/domain_exception.dart';
import 'package:mislukas/core/utils/clock.dart';
import 'package:mislukas/features/budgets/domain/entities/budget.dart';
import 'package:mislukas/features/budgets/domain/entities/budget_alert.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/budgets/domain/usecases/carry_over_budgets.dart';
import 'package:mislukas/features/budgets/domain/usecases/evaluate_budget_alerts.dart';
import 'package:mislukas/features/budgets/domain/usecases/remove_budget.dart';
import 'package:mislukas/features/budgets/domain/usecases/watch_budget_overview.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/fake_repositories.dart';

void main() {
  final september = DateTime(2026, 9);
  final october = DateTime(2026, 10);
  final octoberClock = FixedClock(DateTime(2026, 10, 2, 9));

  Budget marketBudget({
    String id = 'b-1',
    DateTime? month,
    int limit = 100000,
  }) => Budget(
    id: id,
    categoryId: DefaultCategory.mercado.id,
    month: month ?? september,
    limitAmount: limit,
  );

  group('RemoveBudget', () {
    test('quita el presupuesto', () async {
      final budgets = FakeBudgetRepository([marketBudget()]);

      await RemoveBudget(budgets: budgets, clock: testClock)('b-1');

      expect(budgets.budgets, isEmpty);
      expect(budgets.removed.single.id, 'b-1');
    });

    test('uno inexistente o ya quitado lanza budgetNotFound', () async {
      final budgets = FakeBudgetRepository();
      await expectLater(
        RemoveBudget(budgets: budgets, clock: testClock)('no-existe'),
        throwsA(
          isA<DomainException>().having(
            (e) => e.error,
            'error',
            DomainError.budgetNotFound,
          ),
        ),
      );
    });
  });

  group('CarryOverBudgets', () {
    test('copia al mes del reloj con ids nuevos', () async {
      final budgets = FakeBudgetRepository([marketBudget(limit: 450000)]);

      final copies = await CarryOverBudgets(
        budgets: budgets,
        clock: octoberClock,
        ids: SequentialIdGenerator(),
      )();

      expect(copies.single.id, 'id-1');
      expect(copies.single.month, october);
      expect(copies.single.limitAmount, 450000);
      expect(await budgets.getForMonth(october), hasLength(1));
    });

    test('en el mismo mes no copia de nuevo', () async {
      final budgets = FakeBudgetRepository([marketBudget()]);
      final carryOver = CarryOverBudgets(
        budgets: budgets,
        clock: octoberClock,
        ids: SequentialIdGenerator(),
      );

      await carryOver();
      expect(await carryOver(), isEmpty);
      expect(await budgets.getForMonth(october), hasLength(1));
    });
  });

  group('WatchBudgetOverview', () {
    test('una línea por categoría de gasto con lo gastado del mes', () async {
      final budgets = FakeBudgetRepository([marketBudget(limit: 100000)]);
      final movements = FakeMovementRepository([
        testMovement(amount: 60000, date: DateTime(2026, 9, 3)),
        testMovement(amount: 20000, date: DateTime(2026, 9, 10)),
        testMovement(
          category: DefaultCategory.transporte,
          amount: 5000,
          date: DateTime(2026, 9, 4),
        ),
        // Otro mes e ingresos no cuentan.
        testMovement(amount: 90000, date: DateTime(2026, 8, 30)),
        testMovement(category: DefaultCategory.ingreso, amount: 999999),
      ]);

      final lines = await WatchBudgetOverview(
        budgets: budgets,
        movements: movements,
        clock: testClock,
      )().first;

      expect(lines.map((l) => l.categoryId), [
        DefaultCategory.mercado.id,
        DefaultCategory.transporte.id,
        DefaultCategory.ocio.id,
        DefaultCategory.servicios.id,
        DefaultCategory.restaurantes.id,
        DefaultCategory.otros.id,
      ]);
      final market = lines.first;
      expect(market.spent, 80000);
      expect(market.percent, 80);
      expect(market.remaining, 20000);
      final transport = lines[1];
      expect(transport.budget, isNull);
      expect(transport.spent, 5000);
      expect(transport.percent, 0);
    });
  });

  group('alertas por mes', () {
    test(
      'el mes nuevo empieza sin alertas aunque el anterior las tuviera',
      () async {
        final budgets = FakeBudgetRepository([marketBudget(limit: 100000)]);
        final movements = FakeMovementRepository([
          testMovement(amount: 120000, date: DateTime(2026, 9, 15)),
        ]);
        final september = EvaluateBudgetAlerts(
          budgets: budgets,
          movements: movements,
          clock: testClock,
        );
        expect(
          (await september()).single.threshold,
          BudgetAlertThreshold.exceeded,
        );

        // El 2 de octubre se copia el presupuesto; el gasto de septiembre no
        // cuenta en octubre.
        await CarryOverBudgets(
          budgets: budgets,
          clock: octoberClock,
          ids: SequentialIdGenerator(),
        )();
        final octoberAlerts = EvaluateBudgetAlerts(
          budgets: budgets,
          movements: movements,
          clock: octoberClock,
        );
        expect(await octoberAlerts(), isEmpty);

        // Un gasto de octubre al 80% genera la alerta del 75% de octubre.
        await movements.add(
          testMovement(amount: 80000, date: DateTime(2026, 10, 2)),
        );
        final alert = (await octoberAlerts()).single;
        expect(alert.month, october);
        expect(alert.threshold, BudgetAlertThreshold.warning);
      },
    );
  });
}
