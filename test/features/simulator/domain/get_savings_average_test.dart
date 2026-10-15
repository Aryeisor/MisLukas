import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';
import 'package:mislukas/features/simulator/domain/get_savings_average.dart';
import 'package:mislukas/features/simulator/domain/savings_calculator.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/fake_repositories.dart';

/// Ingreso y gasto de un mes de 2026.
List<Movement> _month(int month, {required int income, required int expense}) =>
    [
      testMovement(
        category: DefaultCategory.ingreso,
        amount: income,
        date: DateTime(2026, month, 5),
      ),
      testMovement(amount: expense, date: DateTime(2026, month, 20)),
    ];

Future<SavingsAverage> _average(List<Movement> movements) => GetSavingsAverage(
  movements: FakeMovementRepository(movements),
  clock: testClock,
)();

void main() {
  test(
    'tres meses con datos: promedia junio a agosto, 420.000 al mes',
    () async {
      final result = await _average([
        ..._month(6, income: 4000000, expense: 3600000), // 400.000
        ..._month(7, income: 4000000, expense: 3550000), // 450.000
        ..._month(8, income: 4000000, expense: 3590000), // 410.000
        // Septiembre aún no termina y mayo está fuera del período.
        ..._month(9, income: 100, expense: 9000000),
        ..._month(5, income: 9000000, expense: 100),
      ]);

      expect(
        result,
        SavingsAverageResult(
          months: [DateTime(2026, 6), DateTime(2026, 7), DateTime(2026, 8)],
          amount: 420000,
        ),
      );
      result as SavingsAverageResult;
      expect(result.from, DateTime(2026, 6));
      expect(result.to, DateTime(2026, 8));
      expect(result.isSaving, isTrue);
      // Valor de referencia del simulador con ese promedio.
      expect(
        savingsWithInterest(monthlyContribution: result.amount, years: 3),
        16716595,
      );
    },
  );

  test('un solo mes con datos: promedia solo agosto', () async {
    final result = await _average([
      ..._month(8, income: 3000000, expense: 2500000),
    ]);
    expect(
      result,
      SavingsAverageResult(months: [DateTime(2026, 8)], amount: 500000),
    );
    result as SavingsAverageResult;
    expect(result.from, result.to);
  });

  test('un mes intermedio sin datos no cuenta en el promedio', () async {
    final result = await _average([
      ..._month(6, income: 4000000, expense: 3000000), // 1.000.000
      ..._month(8, income: 4000000, expense: 3800000), // 200.000
    ]);
    expect(
      result,
      SavingsAverageResult(
        months: [DateTime(2026, 6), DateTime(2026, 8)],
        amount: 600000,
      ),
    );
  });

  test('ningún mes completo con datos: sin datos suficientes', () async {
    expect(await _average([]), const SavingsAverageInsufficientData());
    // Septiembre no es un mes completo y mayo queda fuera de los últimos 3.
    expect(
      await _average([
        ..._month(9, income: 4000000, expense: 1000),
        ..._month(5, income: 4000000, expense: 1000),
      ]),
      isA<SavingsAverageInsufficientData>(),
    );
  });

  test('promedio negativo o cero: no está ahorrando', () async {
    final negative = await _average([
      ..._month(6, income: 1000000, expense: 1200000),
      ..._month(7, income: 1000000, expense: 1000000),
      ..._month(8, income: 1000000, expense: 1100000),
    ]);
    expect((negative as SavingsAverageResult).amount, -100000);
    expect(negative.isSaving, isFalse);

    final zero = await _average([..._month(8, income: 1000, expense: 1000)]);
    expect((zero as SavingsAverageResult).isSaving, isFalse);
  });

  test(
    'los eliminados no cuentan: un mes con solo eliminados no tiene datos',
    () async {
      final result = await _average([
        ..._month(6, income: 1000, expense: 400),
        testMovement(
          category: DefaultCategory.ingreso,
          amount: 1000,
          date: DateTime(2026, 8, 1),
          deletedAt: testToday,
        ),
      ]);
      expect(
        result,
        SavingsAverageResult(months: [DateTime(2026, 6)], amount: 600),
      );
    },
  );
}
