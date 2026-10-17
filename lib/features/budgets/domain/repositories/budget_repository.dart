import '../entities/budget.dart';

/// Acceso a los presupuestos. Las consultas excluyen los eliminados.
abstract interface class BudgetRepository {
  /// Presupuestos del mes que empieza en [month].
  Stream<List<Budget>> watchForMonth(DateTime month);

  Future<List<Budget>> getForMonth(DateTime month);

  Future<Budget?> findById(String id);

  /// Crea o actualiza el presupuesto de la categoría y el mes de [budget].
  ///
  /// Como hay un solo presupuesto activo por categoría y mes, si ya existe uno
  /// se actualiza y conserva su identificador. Uno eliminado no revive: se
  /// crea otro con el id de [budget]. Devuelve el presupuesto guardado.
  Future<Budget> save(Budget budget, {required DateTime at});

  /// Quita el presupuesto [id] con borrado lógico en [at].
  Future<void> remove(String id, {required DateTime at});

  /// Copia al mes [month] los presupuestos del mes anterior más reciente que
  /// tenga alguno (RF-53), con ids nuevos de [newId] y los mismos límites.
  ///
  /// No copia nada si [month] ya tiene algún presupuesto, aunque esté
  /// eliminado: así es idempotente y uno quitado en el mes no vuelve. El mes
  /// de origen se elige contando también los eliminados: si el usuario los
  /// quitó todos, no se copia nada. Devuelve los presupuestos copiados.
  Future<List<Budget>> carryOver({
    required DateTime month,
    required DateTime at,
    required String Function() newId,
  });
}
