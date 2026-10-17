import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/errors/domain_exception.dart';
import 'package:mislukas/features/budgets/data/budgets_providers.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/data/movements_providers.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';
import 'package:mislukas/features/reports/presentation/reports_providers.dart';
import 'package:mislukas/features/simulator/domain/get_savings_average.dart';
import 'package:mislukas/features/simulator/presentation/simulator_providers.dart';

import '../../../helpers/test_container.dart';

/// Gastos con fecha elegida (RF-19) sobre la base local real: cuentan en el
/// mes de su fecha, no en el de su registro. Hoy es el 22 de septiembre de
/// 2026.
void main() {
  late ProviderContainer container;

  Future<Movement> expense(int amount, DateTime date) => container
      .read(registerMovementProvider)
      .call(
        amount: amount,
        categoryId: DefaultCategory.mercado.id,
        origin: MovementOrigin.manual,
        date: date,
      );

  setUp(() async {
    (container, _) = await createTestContainer(seed: false);
    await container
        .read(registerIncomeProvider)
        .call(amount: 1000000, date: DateTime(2026, 9, 1));
    await container
        .read(registerIncomeProvider)
        .call(amount: 900000, date: DateTime(2026, 8, 1));
  });

  test('un gasto de ayer cuenta en el mes actual', () async {
    final saved = await expense(30000, DateTime(2026, 9, 21));
    expect(saved.date, DateTime(2026, 9, 21));

    final summary = await container
        .read(watchMonthSummaryProvider)
        .call()
        .first;
    expect(summary.expenses, 30000);
    expect(summary.available, 970000);
  });

  test(
    'un gasto del mes anterior cuenta en ese mes y no en el actual',
    () async {
      await expense(200000, DateTime(2026, 8, 31));

      final september = await container
          .read(watchMonthSummaryProvider)
          .call()
          .first;
      expect(september.expenses, 0);
      expect(september.available, 1000000);

      final august = await container
          .read(watchMonthSummaryProvider)
          .call(month: DateTime(2026, 8))
          .first;
      expect(august.expenses, 200000);
      expect(august.available, 700000);

      // Reportes: el gasto aparece en agosto, no en septiembre.
      final spendingSeptember = await container
          .read(watchCategorySpendingProvider)
          .call()
          .first;
      expect(spendingSeptember, isEmpty);
      final spendingAugust = await container
          .read(watchCategorySpendingProvider)
          .call(month: DateTime(2026, 8))
          .first;
      expect(spendingAugust.single.amount, 200000);
      final comparison = await container
          .read(compareMonthsProvider)
          .call()
          .first;
      // La comparación de septiembre no tiene gastos de este mes.
      expect(comparison.items.where((i) => i.currentAmount > 0), isEmpty);

      // Alertas: un presupuesto de septiembre no lo cuenta.
      await container
          .read(setBudgetProvider)
          .call(categoryId: DefaultCategory.mercado.id, limitAmount: 100000);
      expect(
        await container.read(evaluateBudgetAlertsProvider).call(),
        isEmpty,
      );

      // Simulador: agosto es el único mes completo con datos.
      final average = await container.read(getSavingsAverageProvider).call();
      expect((average as SavingsAverageResult).amount, 700000);
    },
  );

  test('una fecha futura se rechaza', () async {
    await expectLater(
      expense(1000, DateTime(2026, 9, 23)),
      throwsA(
        isA<DomainException>().having(
          (e) => e.error,
          'error',
          DomainError.futureDate,
        ),
      ),
    );
    final created = await container
        .read(registerMovementProvider)
        .call(
          amount: 1000,
          categoryId: DefaultCategory.mercado.id,
          origin: MovementOrigin.manual,
        );
    // Sin fecha, es hoy.
    expect(created.date, DateTime(2026, 9, 22));
  });

  test('al editar, el gasto pasa al mes de su nueva fecha', () async {
    final saved = await expense(50000, DateTime(2026, 9, 10));
    await container
        .read(updateMovementProvider)
        .call(id: saved.id, date: DateTime(2026, 8, 20));

    final september = await container
        .read(watchMonthSummaryProvider)
        .call()
        .first;
    expect(september.expenses, 0);
    final august = await container
        .read(watchMonthSummaryProvider)
        .call(month: DateTime(2026, 8))
        .first;
    expect(august.expenses, 50000);

    await expectLater(
      container
          .read(updateMovementProvider)
          .call(id: saved.id, date: DateTime(2026, 10, 1)),
      throwsA(isA<DomainException>()),
    );
  });
}
