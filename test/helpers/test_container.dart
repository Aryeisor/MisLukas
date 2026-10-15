import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/utils/clock.dart';

import 'pump_screen.dart';
import 'test_database.dart';

/// Contenedor con una base en memoria (sembrada con la demo si [seed]) y el
/// reloj de las pruebas. Se cierra al terminar la prueba.
Future<(ProviderContainer, AppDatabase)> createTestContainer({
  bool seed = true,
  Clock? clock,
  List<Override> overrides = const [],
}) async {
  final db = openTestDatabase();
  if (seed) await testDemoSeed(db, clock: clock).load();
  final container = ProviderContainer(
    overrides: [
      ...databaseOverrides(db, clock: clock),
      ...overrides,
    ],
    retry: (_, _) => null,
  );
  addTearDown(() async {
    container.dispose();
    await db.close();
  });
  return (container, db);
}

/// Espera a que el estado de [provider] cumpla [ready] y lo devuelve. Mantiene
/// el provider escuchado mientras tanto.
Future<T> waitForState<T>(
  ProviderContainer container,
  ProviderListenable<T> provider,
  bool Function(T state) ready,
) async {
  final completer = Completer<T>();
  final subscription = container.listen<T>(provider, (_, next) {
    if (!completer.isCompleted && ready(next)) completer.complete(next);
  }, fireImmediately: true);
  try {
    return await completer.future.timeout(const Duration(seconds: 5));
  } finally {
    subscription.close();
  }
}
