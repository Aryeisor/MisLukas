import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/errors/domain_exception.dart';
import 'package:mislukas/features/budgets/domain/entities/budget.dart';
import 'package:mislukas/features/budgets/domain/entities/budget_alert.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/budgets/domain/usecases/evaluate_budget_alerts.dart';
import 'package:mislukas/features/budgets/domain/usecases/set_budget.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/fake_repositories.dart';

Budget _budget(DefaultCategory category, int limit, {DateTime? month}) =>
    Budget(
      id: 'b-${category.key}',
      categoryId: category.id,
      month: month ?? DateTime(2026, 9),
      limitAmount: limit,
    );

void main() {
  group('evaluateBudgetAlerts', () {
    test(
      'Mercado de la Fase 3: 897.000 de 1.150.000 → 78%, quedan 253.000',
      () {
        final alerts = evaluateBudgetAlerts(
          budgets: [_budget(DefaultCategory.mercado, 1150000)],
          movements: [
            testMovement(amount: 809600),
            testMovement(amount: 87400),
          ],
        );
        final alert = alerts.single;
        expect(alert.percent, 78);
        expect(alert.spent, 897000);
        expect(alert.remaining, 253000);
        expect(alert.threshold, BudgetAlertThreshold.warning);
      },
    );

    test('división entera: 74,9% no alerta; 75% sí', () {
      List<BudgetAlert> evaluate(int spent) => evaluateBudgetAlerts(
        budgets: [_budget(DefaultCategory.mercado, 1000)],
        movements: [testMovement(amount: spent)],
      );
      expect(budgetUsagePercent(spent: 749, limit: 1000), 74);
      expect(evaluate(749), isEmpty);
      expect(evaluate(750).single.threshold, BudgetAlertThreshold.warning);
    });

    test('100% o más es la alerta de exceso con saldo negativo', () {
      final alert = evaluateBudgetAlerts(
        budgets: [_budget(DefaultCategory.ocio, 1000)],
        movements: [testMovement(category: DefaultCategory.ocio, amount: 1200)],
      ).single;
      expect(alert.threshold, BudgetAlertThreshold.exceeded);
      expect(alert.percent, 120);
      expect(alert.remaining, -200);
    });

    test('ignora ingresos, eliminados y otras categorías; ordena por %', () {
      final alerts = evaluateBudgetAlerts(
        budgets: [
          _budget(DefaultCategory.mercado, 1000),
          _budget(DefaultCategory.ocio, 1000),
          _budget(DefaultCategory.servicios, 1000),
        ],
        movements: [
          testMovement(amount: 800),
          testMovement(amount: 5000, deletedAt: testToday),
          testMovement(category: DefaultCategory.ocio, amount: 1000),
          testMovement(category: DefaultCategory.ingreso, amount: 9999),
        ],
      );
      expect(alerts.map((a) => a.categoryId), [
        DefaultCategory.ocio.id,
        DefaultCategory.mercado.id,
      ]);
    });
  });

  group('EvaluateBudgetAlerts y WatchBudgetAlerts', () {
    test('evalúa el mes actual', () async {
      final evaluate = EvaluateBudgetAlerts(
        budgets: FakeBudgetRepository([
          _budget(DefaultCategory.mercado, 1150000),
          _budget(DefaultCategory.mercado, 100, month: DateTime(2026, 8)),
        ]),
        movements: FakeMovementRepository(phase3Movements()),
        clock: testClock,
      );
      final alerts = await evaluate();
      expect(alerts.single.percent, 78);
      expect(alerts.single.month, DateTime(2026, 9));
    });

    test('sin presupuestos no hay alertas', () async {
      final evaluate = EvaluateBudgetAlerts(
        budgets: FakeBudgetRepository(),
        movements: FakeMovementRepository(phase3Movements()),
        clock: testClock,
      );
      expect(await evaluate(), isEmpty);
    });

    test('la alerta aparece al registrar un gasto', () async {
      final movements = FakeMovementRepository();
      final alerts = WatchBudgetAlerts(
        budgets: FakeBudgetRepository([_budget(DefaultCategory.mercado, 1000)]),
        movements: movements,
        clock: testClock,
      )();

      final expectation = expectLater(
        alerts,
        emitsInOrder([
          isEmpty,
          predicate<List<BudgetAlert>>((list) => list.single.percent == 80),
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      await movements.add(testMovement(amount: 800));
      await expectation;
    });
  });

  group('SetBudget', () {
    late FakeBudgetRepository budgets;
    late SetBudget setBudget;

    setUp(() {
      budgets = FakeBudgetRepository();
      setBudget = SetBudget(
        budgets: budgets,
        categories: FakeCategoryRepository(),
        clock: testClock,
        ids: SequentialIdGenerator(),
      );
    });

    test('crea el presupuesto del mes actual (primer día)', () async {
      final budget = await setBudget(
        categoryId: DefaultCategory.mercado.id,
        limitAmount: 1150000,
      );
      expect(budget.month, DateTime(2026, 9));
      expect(budget.limitAmount, 1150000);
      expect(budgets.budgets, [budget]);
    });

    test('actualiza el existente de la misma categoría y mes', () async {
      final first = await setBudget(
        categoryId: DefaultCategory.mercado.id,
        limitAmount: 1000,
      );
      final second = await setBudget(
        categoryId: DefaultCategory.mercado.id,
        limitAmount: 2000,
        month: DateTime(2026, 9, 30),
      );
      expect(second.id, first.id);
      expect(budgets.budgets.single.limitAmount, 2000);
    });

    test(
      'rechaza límites no positivos, categorías inexistentes e Ingreso',
      () async {
        for (final limit in [null, 0, -1]) {
          await expectLater(
            setBudget(categoryId: DefaultCategory.ocio.id, limitAmount: limit),
            throwsA(
              isA<DomainException>().having(
                (e) => e.error,
                'error',
                DomainError.invalidAmount,
              ),
            ),
          );
        }
        await expectLater(
          setBudget(categoryId: 'x', limitAmount: 10),
          throwsA(isA<DomainException>()),
        );
        await expectLater(
          setBudget(categoryId: DefaultCategory.ingreso.id, limitAmount: 10),
          throwsA(
            isA<DomainException>().having(
              (e) => e.error,
              'error',
              DomainError.invalidCategory,
            ),
          ),
        );
        expect(budgets.budgets, isEmpty);
      },
    );
  });
}
