import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';
import 'package:mislukas/features/movements/domain/entities/movement_filter.dart';
import 'package:mislukas/features/movements/domain/usecases/watch_movement_history.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/fake_repositories.dart';

void main() {
  late FakeMovementRepository movements;
  late WatchMovementHistory history;

  setUp(() {
    movements = FakeMovementRepository([
      testMovement(id: 'sep-1', amount: 1000, date: DateTime(2026, 9, 20)),
      testMovement(
        id: 'sep-2',
        category: DefaultCategory.ingreso,
        amount: 8000,
        date: DateTime(2026, 9, 1),
      ),
      testMovement(id: 'ago-1', amount: 2000, date: DateTime(2026, 8, 10)),
      testMovement(id: 'jul-1', amount: 3000, date: DateTime(2026, 7, 5)),
      testMovement(
        id: 'eliminado',
        amount: 500,
        date: DateTime(2026, 9, 21),
        deletedAt: testToday,
      ),
    ]);
    history = WatchMovementHistory(movements: movements);
  });

  test(
    'agrupa por mes, del más reciente al más antiguo, con totales',
    () async {
      final page = await history(monthCount: 3).first;

      expect(page.hasMore, isFalse);
      expect(page.months.map((m) => m.summary.month), [
        DateTime(2026, 9),
        DateTime(2026, 8),
        DateTime(2026, 7),
      ]);
      final september = page.months.first;
      expect(september.movements.map((m) => m.id), ['sep-1', 'sep-2']);
      expect(september.summary.income, 8000);
      expect(september.summary.expenses, 1000);
      // El eliminado no aparece ni cuenta.
      expect(
        page.months.expand((m) => m.movements).map((m) => m.id),
        isNot(contains('eliminado')),
      );
    },
  );

  test('solo carga los meses pedidos e indica si hay más', () async {
    final page = await history(monthCount: 2).first;

    expect(page.months, hasLength(2));
    expect(page.months.last.summary.month, DateTime(2026, 8));
    expect(page.hasMore, isTrue);

    final all = await history(monthCount: 4).first;
    expect(all.months, hasLength(3));
    expect(all.hasMore, isFalse);
  });

  test('con filtro solo muestra los movimientos que lo cumplen', () async {
    final incomes = await history(
      filter: const MovementFilter(type: MovementType.income),
    ).first;
    expect(incomes.months.single.movements.single.id, 'sep-2');
    expect(incomes.months.single.summary.expenses, 0);
  });

  test('sin movimientos, la página está vacía', () async {
    final page = await WatchMovementHistory(movements: FakeMovementRepository())
        .call()
        .first;
    expect(page.isEmpty, isTrue);
    expect(page.hasMore, isFalse);
  });

  test('se actualiza al registrar un movimiento en un mes nuevo', () async {
    final pages = history(monthCount: 3);
    final emitted = <int>[];
    final subscription = pages.listen((p) => emitted.add(p.months.length));
    await pumpEventQueue();
    expect(emitted.last, 3);

    await movements.add(testMovement(date: DateTime(2026, 6, 2)));
    await pumpEventQueue();
    // Sigue mostrando 3 meses, pero ahora hay uno más antiguo.
    expect(emitted.last, 3);
    final page = await history(monthCount: 3).first;
    expect(page.hasMore, isTrue);
    await subscription.cancel();
  });
}
