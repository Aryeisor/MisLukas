import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/category_style.dart';

// Datos de prueba de la Fase 3. Viven en memoria y se reemplazan en la Fase 4
// por la base local (Drift) y los casos de uso, sin tocar las vistas.

/// Fecha de referencia de la demo ("hoy").
final DateTime demoReferenceDate = DateTime(2026, 9, 22);

/// Nombre de la usuaria de la demo.
const String demoUserName = 'Camila';

/// Movimiento de la demo. Es ingreso si su categoría es [CategoryKind.ingreso].
class DemoMovement {
  const DemoMovement({
    required this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.amount,
  });

  final String id;
  final String title;
  final CategoryKind category;
  final DateTime date;

  /// Monto en pesos, siempre positivo.
  final int amount;

  bool get isIncome => category == CategoryKind.ingreso;
}

/// Movimientos iniciales de septiembre, del más reciente al más antiguo.
final List<DemoMovement> demoInitialMovements = [
  DemoMovement(
    id: 'demo-1',
    title: 'Éxito',
    category: CategoryKind.mercado,
    date: DateTime(2026, 9, 22),
    amount: 87400,
  ),
  DemoMovement(
    id: 'demo-2',
    title: 'TransMilenio',
    category: CategoryKind.transporte,
    date: DateTime(2026, 9, 21),
    amount: 5600,
  ),
  DemoMovement(
    id: 'demo-3',
    title: 'Salario',
    category: CategoryKind.ingreso,
    date: DateTime(2026, 9, 1),
    amount: 3800000,
  ),
  DemoMovement(
    id: 'demo-4',
    title: 'Juan Valdez',
    category: CategoryKind.ocio,
    date: DateTime(2026, 9, 1),
    amount: 18500,
  ),
  DemoMovement(
    id: 'demo-5',
    title: 'Freelance',
    category: CategoryKind.ingreso,
    date: DateTime(2026, 9, 1),
    amount: 450000,
  ),
];

// Los totales del mes de la demo son fijos (ingresos $4.250.000 y gastos
// $2.375.680) y no salen solo de los 5 movimientos listados. La diferencia se
// modela como movimientos del mes que no se listan, para que al agregar un
// gasto los totales se recalculen a partir de la lista.

/// Ingresos del mes que no están en la lista: 4.250.000 − 4.250.000.
const int demoUnlistedIncome = 0;

/// Gastos del mes que no están en la lista: 2.375.680 − 111.500.
const int demoUnlistedExpenses = 2264180;

/// Presupuesto mensual de una categoría.
class DemoBudget {
  const DemoBudget({
    required this.category,
    required this.limit,
    required this.unlistedSpent,
  });

  final CategoryKind category;
  final int limit;

  /// Gastado en el mes por movimientos que no están en la lista.
  final int unlistedSpent;
}

/// Presupuestos de la demo. Mercado: límite $1.150.000, gastado $897.000
/// (809.600 no listados + Éxito 87.400) → 78%, quedan $253.000.
const List<DemoBudget> demoBudgets = [
  DemoBudget(
    category: CategoryKind.mercado,
    limit: 1150000,
    unlistedSpent: 809600,
  ),
];

/// Gastos por categoría que no están en la lista, por mes (clave: día 1 del
/// mes). Septiembre suma [demoUnlistedExpenses] y su Mercado coincide con el
/// presupuesto; junto con los movimientos listados da los totales de Reportes:
/// Mercado 897.000, Transporte 427.600, Ocio 522.650, Servicios 308.840 y
/// Otros 219.590. Agosto no tiene movimientos listados.
final Map<DateTime, Map<CategoryKind, int>> demoUnlistedExpensesByMonth = {
  DateTime(2026, 9): const {
    CategoryKind.mercado: 809600,
    CategoryKind.transporte: 422000,
    CategoryKind.ocio: 504150,
    CategoryKind.servicios: 308840,
    CategoryKind.otros: 219590,
  },
  DateTime(2026, 8): const {
    CategoryKind.mercado: 801000,
    CategoryKind.transporte: 464800,
    CategoryKind.ocio: 399000,
    CategoryKind.servicios: 321700,
    CategoryKind.otros: 209100,
  },
};

/// Ahorro promedio de los últimos 3 meses completos (junio a agosto de 2026).
/// En la Fase 4 se calcula con los movimientos guardados.
const int demoAverageMonthlySavings = 420000;

/// Nombre completo y correo de la usuaria de la demo.
const String demoUserFullName = 'Camila Rodríguez';
const String demoUserEmail = 'camila@correo.com';

/// "Hoy" en la demo. Se puede sobrescribir en pruebas.
final demoTodayProvider = Provider<DateTime>((ref) => demoReferenceDate);

/// Movimientos con los que arranca la demo. Se puede sobrescribir en pruebas.
final demoSeedMovementsProvider = Provider<List<DemoMovement>>(
  (ref) => demoInitialMovements,
);

/// Gastos no listados por mes. Se puede sobrescribir en pruebas.
final demoUnlistedExpensesByMonthProvider =
    Provider<Map<DateTime, Map<CategoryKind, int>>>(
      (ref) => demoUnlistedExpensesByMonth,
    );

/// Ahorro promedio mensual; null si no hay datos suficientes para calcularlo.
/// Se puede sobrescribir en pruebas.
final demoAverageSavingsProvider = Provider<int?>(
  (ref) => demoAverageMonthlySavings,
);

/// Lista de movimientos en memoria, del más reciente al más antiguo.
final demoMovementsProvider =
    NotifierProvider<DemoMovementsNotifier, List<DemoMovement>>(
      DemoMovementsNotifier.new,
    );

class DemoMovementsNotifier extends Notifier<List<DemoMovement>> {
  int _nextId = 0;

  @override
  List<DemoMovement> build() {
    final seed = ref.watch(demoSeedMovementsProvider);
    _nextId = seed.length + 1;
    return List.unmodifiable(seed);
  }

  /// Agrega un gasto con fecha de hoy al inicio de la lista.
  void addExpense({
    required String title,
    required CategoryKind category,
    required int amount,
  }) {
    final movement = DemoMovement(
      id: 'demo-${_nextId++}',
      title: title,
      category: category,
      date: ref.read(demoTodayProvider),
      amount: amount,
    );
    state = List.unmodifiable([movement, ...state]);
  }
}
