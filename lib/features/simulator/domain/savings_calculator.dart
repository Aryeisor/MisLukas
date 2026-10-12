import 'dart:math' as math;

// Cálculos del simulador de ahorro (CLAUDE.md, reglas de negocio). Dart puro.
// El cálculo interno se hace en double y los resultados se redondean a pesos.

/// Tasa efectiva anual estimada del simulador (7% EA).
const double annualSavingsRate = 0.07;

/// Tasa mensual equivalente: r = 1,07^(1/12) − 1.
final double monthlySavingsRate =
    math.pow(1 + annualSavingsRate, 1 / 12).toDouble() - 1;

/// Resultado de ahorrar un aporte mensual durante [years] años.
class SavingsProjection {
  const SavingsProjection({
    required this.years,
    required this.withoutInterest,
    required this.withInterest,
  });

  final int years;

  /// Ahorro simple: aporte × meses.
  final int withoutInterest;

  /// Ahorro con interés compuesto mensual al 7% EA.
  final int withInterest;

  /// Lo que se gana en intereses.
  int get interest => withInterest - withoutInterest;
}

int _months(int years) {
  if (years < 1) {
    throw ArgumentError.value(years, 'years', 'Debe ser al menos 1 año');
  }
  return years * 12;
}

/// Sin interés = P × n.
int savingsWithoutInterest({
  required int monthlyContribution,
  required int years,
}) {
  return monthlyContribution * _months(years);
}

/// Con interés = P × ((1 + r)^n − 1) / r.
int savingsWithInterest({required int monthlyContribution, required int years}) {
  final n = _months(years);
  final r = monthlySavingsRate;
  final factor = (math.pow(1 + r, n) - 1) / r;
  return (monthlyContribution * factor).round();
}

/// Proyección a [years] años con y sin interés.
SavingsProjection projectSavings({
  required int monthlyContribution,
  required int years,
}) {
  return SavingsProjection(
    years: years,
    withoutInterest: savingsWithoutInterest(
      monthlyContribution: monthlyContribution,
      years: years,
    ),
    withInterest: savingsWithInterest(
      monthlyContribution: monthlyContribution,
      years: years,
    ),
  );
}

/// Serie año a año, del año 1 al año [years].
List<SavingsProjection> projectSavingsByYear({
  required int monthlyContribution,
  required int years,
}) {
  _months(years);
  return [
    for (var year = 1; year <= years; year++)
      projectSavings(monthlyContribution: monthlyContribution, years: year),
  ];
}
