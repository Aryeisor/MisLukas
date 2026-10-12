import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/widgets/widgets.dart';

import '../../helpers/pump_themed.dart';

void main() {
  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('formatea con puntos de miles y entrega el int', (tester) async {
    int? value;
    await pumpThemed(tester, AppAmountField(onChanged: (v) => value = v));

    await tester.enterText(find.byType(TextField), '87400');
    await tester.pump();

    expect(fieldText(tester), '87.400');
    expect(value, 87400);
  });

  testWidgets('descarta los caracteres que no son dígitos', (tester) async {
    int? value;
    await pumpThemed(tester, AppAmountField(onChanged: (v) => value = v));

    await tester.enterText(find.byType(TextField), '1a2-3,4');
    await tester.pump();

    expect(fieldText(tester), '1.234');
    expect(value, 1234);
  });

  testWidgets('entrega null cuando el campo queda vacío', (tester) async {
    int? value = 1;
    await pumpThemed(
      tester,
      AppAmountField(initialValue: 5600, onChanged: (v) => value = v),
    );

    expect(fieldText(tester), '5.600');

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    expect(value, isNull);
  });
}
