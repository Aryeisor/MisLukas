import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/data/drift_movement_repository.dart';
import 'package:mislukas/features/movements/domain/entities/month_summary.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';
import 'package:mislukas/features/movements/domain/entities/movement_filter.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftMovementRepository repository;

  setUp(() async {
    db = openTestDatabase();
    repository = DriftMovementRepository(db);

    await repository.add(
      testMovement(amount: 1000, date: DateTime(2026, 9, 2)),
    );
    await repository.add(
      testMovement(
        category: DefaultCategory.transporte,
        amount: 2000,
        date: DateTime(2026, 9, 3),
      ),
    );
    await repository.add(
      testMovement(
        category: DefaultCategory.ingreso,
        amount: 5000,
        date: DateTime(2026, 9, 1),
      ),
    );
    await repository.add(
      testMovement(amount: 300, date: DateTime(2026, 7, 31)),
    );
    // Eliminado: no cuenta en ningún total.
    await repository.add(
      testMovement(id: 'eliminado', amount: 999, date: DateTime(2026, 7, 5)),
    );
    await repository.softDelete('eliminado', at: testToday);
  });

  tearDown(() => db.close());

  group('watchMonthSummaries', () {
    test(
      'agrupa por mes, del más reciente al más antiguo, sin eliminados',
      () async {
        final summaries = await repository.watchMonthSummaries().first;

        expect(summaries, [
          MonthSummary(
            month: DateTime(2026, 9),
            income: 5000,
            expenses: 3000,
            movementCount: 3,
          ),
          MonthSummary(
            month: DateTime(2026, 7),
            income: 0,
            expenses: 300,
            movementCount: 1,
          ),
        ]);
      },
    );

    test('con filtro de tipo y de categoría', () async {
      final incomes = await repository
          .watchMonthSummaries(
            filter: const MovementFilter(type: MovementType.income),
          )
          .first;
      expect(incomes, [
        MonthSummary(
          month: DateTime(2026, 9),
          income: 5000,
          expenses: 0,
          movementCount: 1,
        ),
      ]);

      final transport = await repository
          .watchMonthSummaries(
            filter: MovementFilter(categoryId: DefaultCategory.transporte.id),
          )
          .first;
      expect(transport.single.expenses, 2000);
      expect(transport.single.movementCount, 1);
    });

    test('se actualiza al registrar un movimiento', () async {
      final stream = repository.watchMonthSummaries();
      expect(await stream.first, hasLength(2));

      await repository.add(testMovement(date: DateTime(2026, 8, 15)));
      final months = (await stream.first).map((s) => s.month);
      expect(months, [DateTime(2026, 9), DateTime(2026, 8), DateTime(2026, 7)]);
    });
  });

  test('watchBetween filtra por tipo y categoría', () async {
    final september = DateTime(2026, 9);
    final october = DateTime(2026, 10);

    final all = await repository.watchBetween(september, october).first;
    expect(all, hasLength(3));

    final expenses = await repository
        .watchBetween(
          september,
          october,
          filter: const MovementFilter(type: MovementType.expense),
        )
        .first;
    expect(expenses.map((m) => m.amount), [2000, 1000]);

    final market = await repository
        .watchBetween(
          september,
          october,
          filter: MovementFilter(
            type: MovementType.expense,
            categoryId: DefaultCategory.mercado.id,
          ),
        )
        .first;
    expect(market.single.amount, 1000);
  });
}
