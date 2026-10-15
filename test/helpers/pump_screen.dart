import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/app.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/database/database_providers.dart';
import 'package:mislukas/core/theme/app_theme.dart';
import 'package:mislukas/core/utils/clock.dart';
import 'package:mislukas/core/utils/utils_providers.dart';
import 'package:mislukas/core/widgets/widgets.dart';

import 'domain_fixtures.dart';

/// Base en memoria y reloj fijo (22/09/2026) para las pantallas.
List<Override> databaseOverrides(AppDatabase database, {Clock? clock}) => [
  appDatabaseProvider.overrideWithValue(database),
  clockProvider.overrideWithValue(clock ?? testClock),
];

/// Monta una pantalla con ProviderScope y el tema de MisLukas. Con
/// [database], usa esa base y el reloj de las pruebas.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  AppDatabase? database,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (database != null) ...databaseOverrides(database),
        ...overrides,
      ],
      // Sin reintentos: los errores se muestran de inmediato y no dejan
      // timers pendientes.
      retry: (_, _) => null,
      child: MaterialApp(theme: AppTheme.light, home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

/// Monta la app completa con su router.
Future<void> pumpApp(
  WidgetTester tester, {
  AppDatabase? database,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (database != null) ...databaseOverrides(database),
        ...overrides,
      ],
      retry: (_, _) => null,
      child: const MisLukasApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Simula un celular pequeño: 320 x 640 con el texto del sistema al 130%.
void useSmallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Recorre todo el contenido desplazable de la pantalla para construir cada
/// elemento y verifica que no haya overflow ni otros errores de layout.
Future<void> expectNoOverflowWhileScrolling(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  final scrollables = find.byType(Scrollable);
  for (var i = 0; i < scrollables.evaluate().length; i++) {
    final scrollable = scrollables.at(i);
    for (var step = 0; step < 20; step++) {
      await tester.drag(scrollable, const Offset(0, -200), warnIfMissed: false);
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  }
}

/// Inicia sesión en la demo con un correo válido.
Future<void> loginAsDemoUser(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'camila@ejemplo.com');
  await tester.enterText(find.byType(TextField).at(1), 'Clave123*');
  await tester.pump();
  final button = find.widgetWithText(AppPrimaryButton, 'Iniciar sesión');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// Toca una pestaña de la barra inferior.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(AppBottomNav), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}
