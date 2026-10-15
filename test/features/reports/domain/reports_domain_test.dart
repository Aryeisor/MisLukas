import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/reports/domain/entities/category_spending.dart';
import 'package:mislukas/features/reports/domain/entities/month_comparison.dart';
import 'package:mislukas/features/reports/domain/usecases/compare_months.dart';
import 'package:mislukas/features/reports/domain/usecases/watch_category_spending.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/fake_repositories.dart';

void main() {
  group('distributePercentages', () {
    test('el resto mayor ajusta la suma a 100', () {
      expect(distributePercentages([100, 100, 100]), [34, 33, 33]);
      expect(
        distributePercentages([1, 1, 1, 1, 1, 1, 1]).reduce((a, b) => a + b),
        100,
      );
    });

    test('lista vacía o total cero', () {
      expect(distributePercentages([]), isEmpty);
      expect(distributePercentages([0, 0]), [0, 0]);
    });
  });

  group('calculateCategorySpending', () {
    test('ignora ingresos y eliminados; ordena de mayor a menor', () {
      final spending = calculateCategorySpending([
        testMovement(category: DefaultCategory.ocio, amount: 100),
        testMovement(amount: 300),
        testMovement(amount: 50, deletedAt: testToday),
        testMovement(category: DefaultCategory.ingreso, amount: 1000000),
      ]);
      expect(spending, [
        CategorySpending(
          categoryId: DefaultCategory.mercado.id,
          amount: 300,
          percent: 75,
        ),
        CategorySpending(
          categoryId: DefaultCategory.ocio.id,
          amount: 100,
          percent: 25,
        ),
      ]);
    });
  });

  test('percentChange redondea al entero más cercano', () {
    expect(percentChange(current: 897000, previous: 801000), 12);
    expect(percentChange(current: 427600, previous: 464800), -8);
    expect(percentChange(current: 0, previous: 1000), -100);
  });

  group('casos de uso con los datos de la Fase 3', () {
    late FakeMovementRepository movements;

    setUp(() => movements = FakeMovementRepository(phase3Movements()));

    test('WatchCategorySpending: 38/22/18/13/9 que suman 100', () async {
      final spending = await WatchCategorySpending(
        movements: movements,
        clock: testClock,
      )().first;

      expect(spending.map((s) => s.categoryId), [
        DefaultCategory.mercado.id,
        DefaultCategory.ocio.id,
        DefaultCategory.transporte.id,
        DefaultCategory.servicios.id,
        DefaultCategory.otros.id,
      ]);
      expect(spending.map((s) => s.percent), [38, 22, 18, 13, 9]);
      expect(spending.fold<int>(0, (sum, s) => sum + s.amount), 2375680);
      expect(spending.first.amount, 897000);
    });

    test('WatchCategorySpending de un mes sin gastos', () async {
      final spending = await WatchCategorySpending(
        movements: movements,
        clock: testClock,
      )(month: DateTime(2026, 7)).first;
      expect(spending, isEmpty);
    });

    test('CompareMonths: +12/−8/+31/−4/+5 frente a agosto', () async {
      final comparison = await CompareMonths(
        movements: movements,
        clock: testClock,
      )().first;

      expect(comparison.month, DateTime(2026, 9));
      expect(comparison.previousMonth, DateTime(2026, 8));
      final byCategory = {
        for (final item in comparison.items)
          item.categoryId: item.percentChange,
      };
      expect(byCategory, {
        DefaultCategory.mercado.id: 12,
        DefaultCategory.ocio.id: 31,
        DefaultCategory.transporte.id: -8,
        DefaultCategory.servicios.id: -4,
        DefaultCategory.otros.id: 5,
      });
      // Mismo orden que el gasto del mes.
      expect(comparison.items.first.categoryId, DefaultCategory.mercado.id);
      expect(comparison.items.first.isIncrease, isTrue);
    });

    test('CompareMonths omite categorías sin gasto el mes anterior', () async {
      await movements.add(
        testMovement(category: DefaultCategory.restaurantes, amount: 50000),
      );
      final comparison = await CompareMonths(
        movements: movements,
        clock: testClock,
      )().first;
      expect(
        comparison.items.map((i) => i.categoryId),
        isNot(contains(DefaultCategory.restaurantes.id)),
      );
      expect(comparison.items, hasLength(5));
    });

    test('CompareMonths sin mes anterior queda vacío', () async {
      final comparison = await CompareMonths(
        movements: FakeMovementRepository([testMovement(amount: 100)]),
        clock: testClock,
      )().first;
      expect(comparison.isEmpty, isTrue);
    });

    test('compareSpending conserva montos', () {
      final items = compareSpending(
        current: [CategorySpending(categoryId: 'a', amount: 110, percent: 100)],
        previous: {'a': 100},
      );
      expect(
        items.single,
        const CategoryVariation(
          categoryId: 'a',
          currentAmount: 110,
          previousAmount: 100,
          percentChange: 10,
        ),
      );
    });
  });
}
