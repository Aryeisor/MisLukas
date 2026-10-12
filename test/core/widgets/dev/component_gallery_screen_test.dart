import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/theme/app_theme.dart';
import 'package:mislukas/core/widgets/dev/component_gallery_screen.dart';

void main() {
  testWidgets('la galería muestra todos los componentes sin errores', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const ComponentGalleryScreen()),
    );

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
}
