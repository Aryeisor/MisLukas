import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/theme/category_mapping.dart';
import 'package:mislukas/core/theme/category_style.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/data/movements_providers.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';
import 'package:mislukas/features/reports/domain/entities/month_comparison.dart'
    as domain;
import 'package:mislukas/features/reports/presentation/reports_state.dart';
import 'package:mislukas/features/reports/presentation/reports_view_model.dart';

import '../../../helpers/test_container.dart';

void main() {
  Future<ReportsData> readData(
    ProviderContainer container, [
    bool Function(ReportsData data)? ready,
  ]) async {
    final state = await waitForState(
      container,
      reportsViewModelProvider,
      (s) => s is ReportsData && (ready?.call(s) ?? true),
    );
    return state as ReportsData;
  }

  group('ReportsViewModel con la base sembrada', () {
    test('total del mes y encabezados', () async {
      final (container, _) = await createTestContainer();
      final data = await readData(container);

      expect(data.total, 2375680);
      expect(data.monthLabel, 'Septiembre 2026');
      expect(data.monthName, 'septiembre');
      expect(data.shortMonthLabel, 'Sep 2026');
      expect(data.comparison!.previousMonthLabel, 'agosto 2026');
    });

    test('porcentajes de mayor a menor que suman 100', () async {
      final (container, _) = await createTestContainer();
      final shares = (await readData(container)).shares;

      expect(shares.map((s) => s.category), [
        CategoryKind.mercado,
        CategoryKind.ocio,
        CategoryKind.transporte,
        CategoryKind.servicios,
        CategoryKind.otros,
      ]);
      expect(shares.map((s) => s.amount), [
        897000,
        522650,
        427600,
        308840,
        219590,
      ]);
      expect(shares.map((s) => s.percent), [38, 22, 18, 13, 9]);
    });

    test('variaciones frente a agosto con fracciones de barra', () async {
      final (container, _) = await createTestContainer();
      final items = (await readData(container)).comparison!.items;
      final byCategory = {for (final i in items) i.category: i};

      expect(byCategory[CategoryKind.mercado]!.percentChange, 12);
      expect(byCategory[CategoryKind.transporte]!.percentChange, -8);
      expect(byCategory[CategoryKind.ocio]!.percentChange, 31);
      expect(byCategory[CategoryKind.servicios]!.percentChange, -4);
      expect(byCategory[CategoryKind.otros]!.percentChange, 5);

      // Mismo orden que la leyenda; la mayor variación llena la barra.
      expect(items.first.category, CategoryKind.mercado);
      expect(byCategory[CategoryKind.ocio]!.fraction, 1);
      expect(
        byCategory[CategoryKind.mercado]!.fraction,
        closeTo(12 / 31, 1e-9),
      );
      expect(byCategory[CategoryKind.ocio]!.isIncrease, isTrue);
      expect(byCategory[CategoryKind.transporte]!.isIncrease, isFalse);
    });

    test('un gasto nuevo actualiza Reportes', () async {
      final (container, _) = await createTestContainer();
      container.listen(reportsViewModelProvider, (_, _) {});
      await readData(container);

      await container
          .read(registerMovementProvider)
          .call(
            amount: 100000,
            categoryId: DefaultCategory.mercado.id,
            origin: MovementOrigin.manual,
          );

      final data = await readData(
        container,
        (d) =>
            d.total == 2475680 && d.comparison!.items.first.percentChange != 12,
      );
      expect(data.shares.first.amount, 997000);
      expect(data.shares.fold<int>(0, (sum, s) => sum + s.percent), 100);
    });

    test('sin gastos en el mes: estado vacío', () async {
      final (container, _) = await createTestContainer(seed: false);
      final state = await waitForState(
        container,
        reportsViewModelProvider,
        (s) => s is! ReportsLoading,
      );
      expect(state, isA<ReportsEmpty>());
      expect((state as ReportsEmpty).monthName, 'septiembre');
    });
  });

  group('buildReportsState', () {
    test('sin categorías comparables: sin comparación', () {
      final state = buildReportsState(
        month: DateTime(2026, 9),
        spending: const [],
        comparison: domain.MonthComparison(
          month: DateTime(2026, 9),
          previousMonth: DateTime(2026, 8),
          items: const [],
        ),
      );
      expect(state, isA<ReportsEmpty>());
    });

    test('toVariations: sin variación la barra queda vacía', () {
      final items = toVariations([
        domain.CategoryVariation(
          categoryId: CategoryKind.ocio.categoryId,
          currentAmount: 1000,
          previousAmount: 1000,
          percentChange: 0,
        ),
      ]);
      expect(items.single.category, CategoryKind.ocio);
      expect(items.single.fraction, 0);
    });
  });
}
