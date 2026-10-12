import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/demo/demo_data.dart';
import 'package:mislukas/core/theme/category_style.dart';
import 'package:mislukas/features/reports/presentation/reports_state.dart';
import 'package:mislukas/features/reports/presentation/reports_view_model.dart';

void main() {
  final today = DateTime(2026, 9, 22);

  ReportsData demoReport() {
    final state = buildReportsState(
      movements: demoInitialMovements,
      today: today,
      unlistedByMonth: demoUnlistedExpensesByMonth,
    );
    return state as ReportsData;
  }

  test('gastos por categoría de septiembre: no listados + movimientos', () {
    final september = expensesByCategory(
      month: DateTime(2026, 9),
      movements: demoInitialMovements,
      unlistedByMonth: demoUnlistedExpensesByMonth,
    );
    expect(september, {
      CategoryKind.mercado: 897000,
      CategoryKind.transporte: 427600,
      CategoryKind.ocio: 522650,
      CategoryKind.servicios: 308840,
      CategoryKind.otros: 219590,
    });
  });

  test('total del mes y encabezados', () {
    final data = demoReport();
    expect(data.total, 2375680);
    expect(data.monthLabel, 'Septiembre 2026');
    expect(data.monthName, 'septiembre');
    expect(data.shortMonthLabel, 'Sep 2026');
    expect(data.comparison!.previousMonthLabel, 'agosto 2026');
  });

  test('porcentajes de mayor a menor que suman 100', () {
    final shares = demoReport().shares;
    expect(shares.map((s) => s.category), [
      CategoryKind.mercado,
      CategoryKind.ocio,
      CategoryKind.transporte,
      CategoryKind.servicios,
      CategoryKind.otros,
    ]);
    expect(shares.map((s) => s.percent), [38, 22, 18, 13, 9]);
    expect(shares.fold<int>(0, (sum, s) => sum + s.percent), 100);
  });

  test('el resto mayor ajusta la suma a 100', () {
    // Tres partes iguales: 33 + 33 + 33 = 99 sin ajuste.
    final shares = distributePercentages({
      CategoryKind.mercado: 100,
      CategoryKind.ocio: 100,
      CategoryKind.otros: 100,
    });
    expect(shares.fold<int>(0, (sum, s) => sum + s.percent), 100);
    expect(shares.map((s) => s.percent).toList()..sort(), [33, 33, 34]);

    expect(distributePercentages({}), isEmpty);
  });

  test('variaciones frente a agosto con fracciones de barra', () {
    final items = demoReport().comparison!.items;
    final byCategory = {for (final i in items) i.category: i};

    expect(byCategory[CategoryKind.mercado]!.percentChange, 12);
    expect(byCategory[CategoryKind.transporte]!.percentChange, -8);
    expect(byCategory[CategoryKind.ocio]!.percentChange, 31);
    expect(byCategory[CategoryKind.servicios]!.percentChange, -4);
    expect(byCategory[CategoryKind.otros]!.percentChange, 5);

    // Mismo orden que la leyenda; la mayor variación llena la barra.
    expect(items.first.category, CategoryKind.mercado);
    expect(byCategory[CategoryKind.ocio]!.fraction, 1);
    expect(byCategory[CategoryKind.mercado]!.fraction, closeTo(12 / 31, 1e-9));
    expect(byCategory[CategoryKind.ocio]!.isIncrease, isTrue);
    expect(byCategory[CategoryKind.transporte]!.isIncrease, isFalse);
  });

  test('percentChange redondea al entero más cercano', () {
    expect(percentChange(current: 897000, previous: 801000), 12);
    expect(percentChange(current: 427600, previous: 464800), -8);
    expect(percentChange(current: 0, previous: 1000), -100);
  });

  test('sin gastos en el mes: estado vacío', () {
    final state = buildReportsState(
      movements: const [],
      today: today,
      unlistedByMonth: const {},
    );
    expect(state, isA<ReportsEmpty>());
    expect((state as ReportsEmpty).monthName, 'septiembre');
  });

  test('los ingresos no cuentan como gastos', () {
    final state = buildReportsState(
      movements: [
        DemoMovement(
          id: 'i',
          title: 'Salario',
          category: CategoryKind.ingreso,
          date: today,
          amount: 3800000,
        ),
      ],
      today: today,
    );
    expect(state, isA<ReportsEmpty>());
  });

  test('sin gastos en el mes anterior: sin comparación', () {
    final state = buildReportsState(
      movements: demoInitialMovements,
      today: today,
      unlistedByMonth: {
        DateTime(2026, 9): demoUnlistedExpensesByMonth[DateTime(2026, 9)]!,
      },
    );
    expect((state as ReportsData).comparison, isNull);
  });

  test('un gasto nuevo actualiza Reportes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(demoMovementsProvider.notifier)
        .addExpense(
          title: 'Carulla',
          category: CategoryKind.mercado,
          amount: 100000,
        );

    final data = container.read(reportsViewModelProvider) as ReportsData;
    expect(data.total, 2475680);
    expect(data.shares.first.amount, 997000);
    expect(data.shares.fold<int>(0, (sum, s) => sum + s.percent), 100);
  });
}
