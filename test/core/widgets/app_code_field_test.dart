import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/widgets/widgets.dart';

import '../../helpers/pump_themed.dart';

void main() {
  testWidgets('solo acepta dígitos, máximo 6, y avisa al completar', (
    tester,
  ) async {
    final changes = <String>[];
    String? completed;
    await pumpThemed(
      tester,
      AppCodeField(onChanged: changes.add, onCompleted: (c) => completed = c),
    );

    await tester.enterText(find.byType(TextField), '12a3');
    await tester.pump();
    expect(changes.last, '123');
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(completed, isNull);

    await tester.enterText(find.byType(TextField), '12345678');
    await tester.pump();
    expect(changes.last, '123456');
    expect(completed, '123456');
  });

  testWidgets('muestra el error debajo de las casillas', (tester) async {
    await pumpThemed(
      tester,
      const AppCodeField(errorText: 'El código no es válido'),
    );
    expect(find.text('El código no es válido'), findsOneWidget);
  });

  testWidgets('tiene etiqueta para lectores de pantalla', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpThemed(tester, const AppCodeField());
    expect(find.bySemanticsLabel('Código de verificación'), findsOneWidget);
    handle.dispose();
  });
}
