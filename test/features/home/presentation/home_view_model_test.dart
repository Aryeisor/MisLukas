import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/theme/category_mapping.dart';
import 'package:mislukas/core/theme/category_style.dart';
import 'package:mislukas/features/budgets/domain/entities/budget_alert.dart'
    as domain;
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/home/presentation/home_state.dart';
import 'package:mislukas/features/home/presentation/home_view_model.dart';
import 'package:mislukas/features/movements/data/movements_providers.dart';
import 'package:mislukas/features/movements/domain/entities/month_summary.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/test_container.dart';

void main() {
  Future<HomeData> readData(
    ProviderContainer container, [
    bool Function(HomeData data)? ready,
  ]) async {
    final state = await waitForState(
      container,
      homeViewModelProvider,
      (s) => s is HomeData && (ready?.call(s) ?? true),
    );
    return state as HomeData;
  }

  group('HomeViewModel con la base sembrada', () {
    test('calcula ingresos, gastos y disponible del mes', () async {
      final (container, _) = await createTestContainer();
      final data = await readData(container);

      expect(data.monthLabel, 'Septiembre 2026');
      expect(data.userName, 'Camila');
      expect(data.income, 4250000);
      expect(data.expenses, 2375680);
      expect(data.available, 1874320);
    });

    test('muestra la alerta de Mercado al 78% con 253.000 restantes', () async {
      final (container, _) = await createTestContainer();
      final alert = (await readData(container)).budgetAlert!;

      expect(alert.category, CategoryKind.mercado);
      expect(alert.percent, 78);
      expect(alert.remaining, 253000);
    });

    test('lista los 5 últimos movimientos con su fecha relativa', () async {
      final (container, _) = await createTestContainer();
      final items = (await readData(container)).latestMovements;

      expect(items.map((m) => m.title), [
        'Éxito',
        'TransMilenio',
        'Uber',
        'Bar El Chorro',
        'D1',
      ]);
      expect(items.map((m) => m.dateLabel), [
        'Hoy',
        'Ayer',
        'Sep 20',
        'Sep 19',
        'Sep 18',
      ]);
    });

    test('registrar un gasto de Mercado actualiza totales, alerta y lista', () async {
      final (container, _) = await createTestContainer();
      container.listen(homeViewModelProvider, (_, _) {});
      await readData(container);

      await container
          .read(registerMovementProvider)
          .call(
            amount: 50000,
            categoryId: DefaultCategory.mercado.id,
            origin: MovementOrigin.manual,
            note: 'Carulla',
          );

      // Cada stream se actualiza por su cuenta; espera a que lleguen los tres.
      final data = await readData(
        container,
        (d) =>
            d.expenses != 2375680 &&
            d.budgetAlert?.percent != 78 &&
            d.latestMovements.first.title == 'Carulla',
      );
      expect(data.expenses, 2375680 + 50000);
      expect(data.available, 1874320 - 50000);
      expect(data.income, 4250000);
      // 947.000 / 1.150.000 = 82%.
      expect(data.budgetAlert!.percent, 82);
      expect(data.budgetAlert!.remaining, 203000);
      expect(data.latestMovements.first.title, 'Carulla');
      expect(data.latestMovements.first.dateLabel, 'Hoy');
      expect(data.latestMovements, hasLength(5));
    });

    test('sin movimientos en el mes el estado es vacío', () async {
      final (container, _) = await createTestContainer(seed: false);
      final state = await waitForState(
        container,
        homeViewModelProvider,
        (s) => s is! HomeLoading,
      );
      expect(state, isA<HomeEmpty>());
    });
  });

  group('buildHomeState', () {
    final summary = MonthSummary(
      month: DateTime(2026, 9),
      income: 1000,
      expenses: 400,
      movementCount: 2,
    );

    test('el título es la nota o, si no hay, la descripción', () {
      final state = buildHomeState(
        summary: summary,
        recent: [
          testMovement(description: 'Éxito', note: 'Mercado de la semana'),
          testMovement(
            description: 'Salario',
            category: DefaultCategory.ingreso,
          ),
        ],
        alerts: const [],
        today: testToday,
        userName: 'Camila',
      ) as HomeData;

      expect(state.latestMovements.map((m) => m.title), [
        'Mercado de la semana',
        'Salario',
      ]);
      expect(state.latestMovements.last.category, CategoryKind.ingreso);
      expect(state.budgetAlert, isNull);
      expect(state.available, 600);
    });

    test('toma la alerta con mayor porcentaje', () {
      final state = buildHomeState(
        summary: summary,
        recent: const [],
        alerts: [
          domain.BudgetAlert(
            categoryId: CategoryKind.ocio.categoryId,
            month: DateTime(2026, 9),
            limitAmount: 1000,
            spent: 1200,
            percent: 120,
            threshold: domain.BudgetAlertThreshold.exceeded,
          ),
        ],
        today: testToday,
        userName: 'Camila',
      ) as HomeData;

      expect(state.budgetAlert!.category, CategoryKind.ocio);
      expect(state.budgetAlert!.remaining, -200);
    });

    test('mes sin movimientos: vacío', () {
      final state = buildHomeState(
        summary: MonthSummary(
          month: DateTime(2026, 9),
          income: 0,
          expenses: 0,
          movementCount: 0,
        ),
        recent: [testMovement(date: DateTime(2026, 8, 30))],
        alerts: const [],
        today: testToday,
        userName: 'Camila',
      );
      expect(state, isA<HomeEmpty>());
    });
  });
}
