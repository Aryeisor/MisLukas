import '../../../core/theme/category_style.dart';

/// Estado de la pantalla de Reportes.
sealed class ReportsState {
  const ReportsState();
}

class ReportsLoading extends ReportsState {
  const ReportsLoading();
}

class ReportsError extends ReportsState {
  const ReportsError(this.message);

  final String message;
}

/// Sin gastos en el mes consultado.
class ReportsEmpty extends ReportsState {
  const ReportsEmpty({required this.monthLabel, required this.monthName});

  /// "Septiembre 2026".
  final String monthLabel;

  /// "septiembre".
  final String monthName;
}

class ReportsData extends ReportsState {
  const ReportsData({
    required this.monthLabel,
    required this.monthName,
    required this.shortMonthLabel,
    required this.total,
    required this.shares,
    required this.comparison,
  });

  /// "Septiembre 2026".
  final String monthLabel;

  /// "septiembre".
  final String monthName;

  /// "Sep 2026", en el centro de la dona.
  final String shortMonthLabel;

  /// Total gastado en el mes.
  final int total;

  /// Participación de cada categoría, de mayor a menor gasto.
  final List<CategoryShare> shares;

  /// Comparación con el mes anterior; null si ese mes no tiene gastos.
  final MonthComparison? comparison;
}

/// Gasto de una categoría y su porcentaje del total del mes.
class CategoryShare {
  const CategoryShare({
    required this.category,
    required this.amount,
    required this.percent,
  });

  final CategoryKind category;
  final int amount;

  /// Porcentaje entero; los de todas las categorías suman 100.
  final int percent;
}

/// Variación de los gastos frente al mes anterior.
class MonthComparison {
  const MonthComparison({
    required this.previousMonthLabel,
    required this.items,
  });

  /// "agosto 2026".
  final String previousMonthLabel;
  final List<CategoryVariation> items;
}

/// Variación de una categoría frente al mes anterior.
class CategoryVariation {
  const CategoryVariation({
    required this.category,
    required this.percentChange,
    required this.fraction,
  });

  final CategoryKind category;

  /// Variación porcentual redondeada: positiva si aumentó.
  final int percentChange;

  /// Largo de la barra (0 a 1) respecto a la mayor variación absoluta.
  final double fraction;

  bool get isIncrease => percentChange > 0;
}
