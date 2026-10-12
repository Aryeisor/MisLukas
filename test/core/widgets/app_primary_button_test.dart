import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/widgets/widgets.dart';

import '../../helpers/pump_themed.dart';

void main() {
  testWidgets('llama a onPressed al tocarlo', (tester) async {
    var taps = 0;
    await pumpThemed(
      tester,
      AppPrimaryButton(label: 'Guardar gasto', onPressed: () => taps++),
    );

    await tester.tap(find.byType(AppPrimaryButton));
    expect(taps, 1);
  });

  testWidgets('deshabilitado cuando onPressed es null', (tester) async {
    await pumpThemed(
      tester,
      const AppPrimaryButton(label: 'Crear cuenta', onPressed: null),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.enabled, isFalse);
  });

  testWidgets('isLoading muestra el indicador y bloquea el toque', (
    tester,
  ) async {
    var taps = 0;
    await pumpThemed(
      tester,
      AppPrimaryButton(
        label: 'Guardar gasto',
        onPressed: () => taps++,
        isLoading: true,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Guardar gasto'), findsNothing);

    await tester.tap(find.byType(AppPrimaryButton), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);
  });
}
