import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/database/seed/demo_seed.dart';
import 'package:mislukas/core/utils/clock.dart';
import 'package:mislukas/features/budgets/data/drift_budget_repository.dart';
import 'package:mislukas/features/movements/data/drift_movement_repository.dart';

import 'domain_fixtures.dart';

/// Base Drift en memoria, sin cifrar, para probar repositorios.
AppDatabase openTestDatabase() {
  // Cada prueba abre su propia base a propósito.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

/// Semilla de demo sobre [db] con el reloj de las pruebas (22/09/2026).
DemoSeed testDemoSeed(AppDatabase db, {Clock? clock}) {
  return DemoSeed(
    db: db,
    movements: DriftMovementRepository(db),
    budgets: DriftBudgetRepository(db),
    clock: clock ?? testClock,
    ids: SequentialIdGenerator(),
  );
}

/// Espera [future] dentro de una prueba de widgets. Drift completa sus
/// operaciones con microtareas que solo avanzan al bombear frames del tiempo
/// simulado; esperar el Future directamente puede detener la prueba.
Future<T> pumpUntilDone<T>(WidgetTester tester, Future<T> future) async {
  var done = false;
  late T result;
  Object? error;
  StackTrace? stack;
  future.then(
    (value) {
      result = value;
      done = true;
    },
    onError: (Object e, StackTrace s) {
      error = e;
      stack = s;
      done = true;
    },
  );
  for (var i = 0; i < 100 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  if (!done) fail('La operación de la base no terminó.');
  if (error != null) Error.throwWithStackTrace(error!, stack!);
  return result;
}

/// Identificador del movimiento más reciente con [description].
Future<String> movementIdOf(
  WidgetTester tester,
  AppDatabase db,
  String description,
) async {
  final query = db.select(db.movements)
    ..where((t) => t.description.equals(description))
    ..orderBy([(t) => OrderingTerm.desc(t.date)])
    ..limit(1);
  return (await pumpUntilDone(tester, query.getSingle())).id;
}

/// Prueba de widgets con una base en memoria, sembrada con la demo si [seed]
/// es true. Al terminar desmonta la app antes de cerrar la base: al cancelar
/// sus streams, Drift programa un Timer que debe correr dentro de la prueba.
void testWidgetsWithDatabase(
  String description,
  Future<void> Function(WidgetTester tester, AppDatabase db) body, {
  bool seed = true,
}) {
  testWidgets(description, (tester) async {
    final db = openTestDatabase();
    try {
      // La base se abre (y se siembra) antes de montar la app.
      await pumpUntilDone(
        tester,
        seed ? testDemoSeed(db).load() : db.customSelect('SELECT 1').get(),
      );
      await body(tester, db);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await pumpUntilDone(tester, db.close());
    }
  });
}
