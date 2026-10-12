import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/features/simulator/domain/savings_calculator.dart';

void main() {
  const p = 420000;

  test('tasa mensual equivalente al 7% EA', () {
    expect(monthlySavingsRate, closeTo(0.0056541, 1e-7));
  });

  group('con P = 420.000', () {
    test('1 año', () {
      final result = projectSavings(monthlyContribution: p, years: 1);
      expect(result.withInterest, 5199725);
      expect(result.withoutInterest, 5040000);
    });

    test('2 años', () {
      final result = projectSavings(monthlyContribution: p, years: 2);
      expect(result.withInterest, 10763430);
      expect(result.withoutInterest, 10080000);
    });

    test('3 años e intereses', () {
      final result = projectSavings(monthlyContribution: p, years: 3);
      expect(result.withInterest, 16716595);
      expect(result.withoutInterest, 15120000);
      expect(result.interest, 1596595);
    });
  });

  test('con P = 470.000 a 3 años y diferencia frente a 420.000', () {
    final boosted = savingsWithInterest(monthlyContribution: 470000, years: 3);
    final base = savingsWithInterest(monthlyContribution: p, years: 3);
    expect(boosted, 18706666);
    expect(boosted - base, 1990071);
  });

  test('serie año a año', () {
    final series = projectSavingsByYear(monthlyContribution: p, years: 3);
    expect(series.map((s) => s.years), [1, 2, 3]);
    expect(series.map((s) => s.withInterest), [5199725, 10763430, 16716595]);
    expect(series.map((s) => s.withoutInterest), [5040000, 10080000, 15120000]);
  });

  test('rechaza horizontes menores a 1 año', () {
    expect(
      () => projectSavings(monthlyContribution: p, years: 0),
      throwsArgumentError,
    );
    expect(
      () => projectSavingsByYear(monthlyContribution: p, years: 0),
      throwsArgumentError,
    );
  });
}
