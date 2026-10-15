import '../entities/budget.dart';

/// Acceso a los presupuestos. Las consultas excluyen los eliminados.
abstract interface class BudgetRepository {
  /// Presupuestos del mes que empieza en [month].
  Stream<List<Budget>> watchForMonth(DateTime month);

  Future<List<Budget>> getForMonth(DateTime month);

  /// Crea o actualiza el presupuesto de la categoría y el mes de [budget].
  ///
  /// Como hay un solo presupuesto por categoría y mes, si ya existe uno
  /// (incluso eliminado) se actualiza y conserva su identificador. Devuelve el
  /// presupuesto guardado.
  Future<Budget> save(Budget budget, {required DateTime at});
}
