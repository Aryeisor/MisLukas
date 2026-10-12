import '../../../core/theme/category_style.dart';

/// Estado de la pantalla de Inicio.
sealed class HomeState {
  const HomeState();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeError extends HomeState {
  const HomeError(this.message);

  final String message;
}

/// Sin movimientos en el mes.
class HomeEmpty extends HomeState {
  const HomeEmpty({required this.monthLabel, required this.userName});

  final String monthLabel;
  final String userName;
}

class HomeData extends HomeState {
  const HomeData({
    required this.monthLabel,
    required this.userName,
    required this.income,
    required this.expenses,
    required this.budgetAlert,
    required this.latestMovements,
  });

  final String monthLabel;
  final String userName;
  final int income;
  final int expenses;

  /// Alerta del presupuesto más comprometido, si alguno llega al 75%.
  final BudgetAlert? budgetAlert;
  final List<HomeMovementItem> latestMovements;

  /// Disponible del mes = ingresos − gastos.
  int get available => income - expenses;
}

/// Uso de un presupuesto que llegó al umbral de alerta.
class BudgetAlert {
  const BudgetAlert({
    required this.category,
    required this.percent,
    required this.remaining,
  });

  final CategoryKind category;

  /// Porcentaje entero del límite usado (división entera).
  final int percent;

  /// Lo que queda del límite; negativo si se superó.
  final int remaining;
}

/// Movimiento listo para mostrar en "Últimos movimientos".
class HomeMovementItem {
  const HomeMovementItem({
    required this.id,
    required this.title,
    required this.category,
    required this.dateLabel,
    required this.amount,
  });

  final String id;
  final String title;
  final CategoryKind category;
  final String dateLabel;
  final int amount;
}
