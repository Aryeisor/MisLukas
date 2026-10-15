import 'package:mislukas/core/sync/sync_status.dart';
import 'package:mislukas/core/utils/clock.dart';
import 'package:mislukas/core/utils/id_generator.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';
import 'package:mislukas/features/simulator/domain/get_savings_average.dart';

/// "Hoy" en las pruebas: 22 de septiembre de 2026, como en la demo.
final DateTime testToday = DateTime(2026, 9, 22, 10, 30);
final Clock testClock = FixedClock(testToday);

/// Identificadores predecibles: id-1, id-2…
class SequentialIdGenerator implements IdGenerator {
  int _next = 0;

  @override
  String newId() => 'id-${++_next}';
}

int _counter = 0;

/// Movimiento de prueba. El tipo sale de la categoría.
Movement testMovement({
  String? id,
  DefaultCategory category = DefaultCategory.mercado,
  int amount = 10000,
  DateTime? date,
  String description = 'Prueba',
  String? note,
  MovementOrigin origin = MovementOrigin.manual,
  DateTime? deletedAt,
}) {
  final created = testToday;
  return Movement(
    id: id ?? 'm-${++_counter}',
    type: category.type,
    amount: amount,
    date: dateOnly(date ?? testToday),
    categoryId: category.id,
    description: description,
    note: note,
    origin: origin,
    createdAt: created,
    updatedAt: created,
    deletedAt: deletedAt,
    syncStatus: SyncStatus.pending,
  );
}

// Datos equivalentes a la demo (core/database/seed/demo_seed.dart).

/// Gastos de septiembre por categoría: total $2.375.680.
const Map<DefaultCategory, int> phase3SeptemberExpenses = {
  DefaultCategory.mercado: 897000,
  DefaultCategory.transporte: 427600,
  DefaultCategory.ocio: 522650,
  DefaultCategory.servicios: 308840,
  DefaultCategory.otros: 219590,
};

/// Gastos de agosto por categoría.
const Map<DefaultCategory, int> phase3AugustExpenses = {
  DefaultCategory.mercado: 801000,
  DefaultCategory.transporte: 464800,
  DefaultCategory.ocio: 399000,
  DefaultCategory.servicios: 321700,
  DefaultCategory.otros: 209100,
};

/// Ingresos de septiembre: salario $3.800.000 y freelance $450.000.
const List<int> phase3SeptemberIncome = [3800000, 450000];

/// Movimientos de septiembre y agosto de la demo. Cada gasto por categoría se
/// parte en dos movimientos para probar la suma.
List<Movement> phase3Movements() {
  List<Movement> expenses(Map<DefaultCategory, int> totals, DateTime date) => [
    for (final entry in totals.entries) ...[
      testMovement(category: entry.key, amount: entry.value - 1000, date: date),
      testMovement(
        category: entry.key,
        amount: 1000,
        date: date.add(const Duration(days: 1)),
      ),
    ],
  ];

  return [
    ...expenses(phase3SeptemberExpenses, DateTime(2026, 9, 2)),
    ...expenses(phase3AugustExpenses, DateTime(2026, 8, 10)),
    for (final income in phase3SeptemberIncome)
      testMovement(
        category: DefaultCategory.ingreso,
        amount: income,
        date: DateTime(2026, 9, 1),
      ),
  ];
}

/// Ahorro promedio de junio a agosto de 2026 de [amount]; null es "sin datos
/// suficientes".
SavingsAverage savingsAverageOf(int? amount) => amount == null
    ? const SavingsAverageInsufficientData()
    : SavingsAverageResult(
        months: [DateTime(2026, 6), DateTime(2026, 7), DateTime(2026, 8)],
        amount: amount,
      );
