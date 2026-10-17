import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/features/budgets/data/budgets_providers.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/data/movements_providers.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';
import 'package:mislukas/features/reports/presentation/reports_providers.dart';
import 'package:mislukas/features/simulator/domain/get_savings_average.dart';
import 'package:mislukas/features/simulator/presentation/simulator_providers.dart';

import '../../../helpers/test_container.dart';

/// Ingresos registrados a mano (RegisterIncome) sobre la base local real:
/// cuentan en el disponible y en el simulador, pero no en reportes ni en
/// alertas, que son solo de gastos. Hoy es el 22 de septiembre de 2026.
void main() {
  late ProviderContainer container;

  Future<void> income(int amount, DateTime date, [String text = 'Salario']) =>
      container
          .read(registerIncomeProvider)
          .call(amount: amount, description: text, date: date);

  Future<void> expense(DefaultCategory category, int amount, DateTime date) =>
      container
          .read(registerMovementProvider)
          .call(
            amount: amount,
            categoryId: category.id,
            origin: MovementOrigin.manual,
            date: date,
          );

  setUp(() async {
    (container, _) = await createTestContainer(seed: false);
    // Septiembre: ingresos 3.800.000 + 450.000; gastos 600.000 + 100.000.
    await income(3800000, DateTime(2026, 9, 1));
    await income(450000, DateTime(2026, 9, 15), 'Freelance');
    await expense(DefaultCategory.mercado, 600000, DateTime(2026, 9, 10));
    await expense(DefaultCategory.transporte, 100000, DateTime(2026, 9, 12));
    // Agosto: un ingreso de 2.000.000 y Mercado 500.000.
    await income(2000000, DateTime(2026, 8, 1));
    await expense(DefaultCategory.mercado, 500000, DateTime(2026, 8, 5));
  });

  test('Disponible del mes = ingresos − gastos', () async {
    final summary = await container.read(watchMonthSummaryProvider).call().first;
    expect(summary.income, 4250000);
    expect(summary.expenses, 700000);
    expect(summary.available, 3550000);
    expect(summary.movementCount, 4);
  });

  test('el gráfico y los porcentajes solo tienen gastos', () async {
    final spending = await container
        .read(watchCategorySpendingProvider)
        .call()
        .first;
    expect(spending.map((s) => s.categoryId), [
      DefaultCategory.mercado.id,
      DefaultCategory.transporte.id,
    ]);
    expect(spending.map((s) => s.percent), [86, 14]);
    expect(spending.fold<int>(0, (sum, s) => sum + s.amount), 700000);
  });

  test('la comparación mensual no incluye ingresos', () async {
    final comparison = await container.read(compareMonthsProvider).call().first;
    expect(
      comparison.items.map((i) => i.categoryId),
      isNot(contains(DefaultCategory.ingreso.id)),
    );
    final mercado = comparison.items.singleWhere(
      (i) => i.categoryId == DefaultCategory.mercado.id,
    );
    expect(mercado.previousAmount, 500000);
    expect(mercado.currentAmount, 600000);
  });

  test('un mes con solo ingresos no tiene gastos que mostrar', () async {
    final spending = await container
        .read(watchCategorySpendingProvider)
        .call(month: DateTime(2026, 7))
        .first;
    expect(spending, isEmpty);

    await income(1000000, DateTime(2026, 7, 3));
    final after = await container
        .read(watchCategorySpendingProvider)
        .call(month: DateTime(2026, 7))
        .first;
    expect(after, isEmpty);
  });

  test('las alertas de presupuesto solo cuentan gastos', () async {
    await container
        .read(setBudgetProvider)
        .call(categoryId: DefaultCategory.mercado.id, limitAmount: 800000);
    var alerts = await container.read(evaluateBudgetAlertsProvider).call();
    expect(alerts.single.categoryId, DefaultCategory.mercado.id);
    expect(alerts.single.spent, 600000);
    expect(alerts.single.percent, 75);

    // Un ingreso más no mueve la alerta.
    await income(5000000, DateTime(2026, 9, 20), 'Prima');
    alerts = await container.read(evaluateBudgetAlertsProvider).call();
    expect(alerts.single.spent, 600000);
    expect(alerts.single.percent, 75);
  });

  test('el simulador suma los ingresos registrados a mano', () async {
    // Junio y julio sin datos: solo cuenta agosto (2.000.000 − 500.000).
    final average = await container.read(getSavingsAverageProvider).call();
    expect(average, isA<SavingsAverageResult>());
    expect((average as SavingsAverageResult).amount, 1500000);
    expect(average.months, [DateTime(2026, 8)]);
  });
}
