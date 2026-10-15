import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/seed/demo_seed.dart';
import 'package:mislukas/core/theme/app_theme.dart';
import 'package:mislukas/core/widgets/dev/component_gallery_screen.dart';

void main() {
  // Sin pumpAndSettle: la galería tiene un botón cargando que no se detiene.
  Future<void> pumpGallery(WidgetTester tester, {bool demoTools = true}) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [demoToolsEnabledProvider.overrideWithValue(demoTools)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ComponentGalleryScreen(),
        ),
      ),
    );
  }

  testWidgets('la galería muestra todos los componentes sin errores', (
    tester,
  ) async {
    await pumpGallery(tester);

    // Las acciones de demo están arriba, en modo desarrollo.
    expect(find.text('Cargar datos de demostración'), findsOneWidget);
    expect(find.text('Borrar todos los datos'), findsOneWidget);

    // Recorre la lista completa para construir cada componente.
    await tester.scrollUntilVisible(
      find.text('Snackbar'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('Snackbar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fuera de modo desarrollo no muestra las acciones de demo', (
    tester,
  ) async {
    await pumpGallery(tester, demoTools: false);

    expect(find.text('Cargar datos de demostración'), findsNothing);
    expect(find.text('Borrar todos los datos'), findsNothing);
  });

  testWidgets('el botón destructivo pide confirmación', (tester) async {
    await pumpGallery(tester);

    final button = find.text('Eliminar movimiento');
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('¿Eliminar este movimiento?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('¿Eliminar este movimiento?'), findsNothing);
  });
}
