import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/demo/demo_data.dart';
import 'package:mislukas/core/theme/category_style.dart';
import 'package:mislukas/features/home/presentation/home_state.dart';
import 'package:mislukas/features/home/presentation/home_view_model.dart';

void main() {
  final today = DateTime(2026, 9, 22);

  DemoMovement expense(int amount, {CategoryKind? category, DateTime? date}) =>
      DemoMovement(
        id: 'test-$amount',
        title: 'Gasto',
        category: category ?? CategoryKind.mercado,
        date: date ?? today,
        amount: amount,
      );

  group('HomeViewModel con los datos de la demo', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    HomeData read() => container.read(homeViewModelProvider) as HomeData;

    test('calcula ingresos, gastos y disponible del mes', () {
      final data = read();
      expect(data.monthLabel, 'Septiembre 2026');
      expect(data.userName, 'Camila');
      expect(data.income, 4250000);
      expect(data.expenses, 2375680);
      expect(data.available, 1874320);
    });

    test('muestra la alerta de Mercado al 78% con 253.000 restantes', () {
      final alert = read().budgetAlert!;
      expect(alert.category, CategoryKind.mercado);
      expect(alert.percent, 78);
      expect(alert.remaining, 253000);
    });

    test('lista los movimientos con su fecha relativa', () {
      final items = read().latestMovements;
      expect(items.map((m) => m.title).first, 'Éxito');
      expect(items.map((m) => m.dateLabel), [
        'Hoy',
        'Ayer',
        'Sep 1',
        'Sep 1',
        'Sep 1',
      ]);
    });

    test('agregar un gasto de Mercado actualiza totales, presupuesto y lista', () {
      container
          .read(demoMovementsProvider.notifier)
          .addExpense(
            title: 'Carulla',
            category: CategoryKind.mercado,
            amount: 50000,
          );

      final data = read();
      expect(data.expenses, 2375680 + 50000);
      expect(data.available, 1874320 - 50000);
      expect(data.income, 4250000);
      // 947.000 / 1.150.000 = 82%.
      expect(data.budgetAlert!.percent, 82);
      expect(data.budgetAlert!.remaining, 203000);
      expect(data.latestMovements.first.title, 'Carulla');
      expect(data.latestMovements.first.dateLabel, 'Hoy');
      expect(data.latestMovements, hasLength(latestMovementsLimit));
    });

    test('sin movimientos en el mes el estado es vacío', () {
      final empty = ProviderContainer(
        overrides: [demoSeedMovementsProvider.overrideWithValue(const [])],
      );
      addTearDown(empty.dispose);

      expect(empty.read(homeViewModelProvider), isA<HomeEmpty>());
    });
  });

  group('calculateMonthTotals', () {
    test('ignora movimientos de otros meses', () {
      final totals = calculateMonthTotals(
        movements: [
          expense(1000),
          expense(5000, date: DateTime(2026, 8, 31)),
          DemoMovement(
            id: 'in',
            title: 'Salario',
            category: CategoryKind.ingreso,
            date: today,
            amount: 9000,
          ),
        ],
        today: today,
      );
      expect(totals.income, 9000);
      expect(totals.expenses, 1000);
    });
  });

  group('selectBudgetAlert', () {
    const budget = DemoBudget(
      category: CategoryKind.mercado,
      limit: 1000,
      unlistedSpent: 0,
    );

    BudgetAlert? alertFor(int spent) => selectBudgetAlert(
      budgets: const [budget],
      movements: [expense(spent)],
      today: today,
    );

    test('aparece al llegar al 75%', () {
      expect(alertFor(750)?.percent, 75);
    });

    test('no aparece por debajo del 75%, ni con 74,9%', () {
      expect(alertFor(740), isNull);
      expect(
        selectBudgetAlert(
          budgets: const [
            DemoBudget(
              category: CategoryKind.mercado,
              limit: 10000,
              unlistedSpent: 0,
            ),
          ],
          movements: [expense(7499)],
          today: today,
        ),
        isNull,
      );
    });

    test('con más del 100% el restante es negativo', () {
      final alert = alertFor(1200)!;
      expect(alert.percent, 120);
      expect(alert.remaining, -200);
    });

    test('solo cuenta gastos de la categoría del presupuesto', () {
      expect(
        selectBudgetAlert(
          budgets: const [budget],
          movements: [expense(900, category: CategoryKind.ocio)],
          today: today,
        ),
        isNull,
      );
    });
  });
}
