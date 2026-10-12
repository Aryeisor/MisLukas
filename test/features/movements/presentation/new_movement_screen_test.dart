import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/movements/presentation/new_movement_screen.dart';

import '../../../helpers/pump_screen.dart';

void main() {
  bool selected(WidgetTester tester, String title) => tester
      .widget<SelectableOptionCard>(
        find.widgetWithText(SelectableOptionCard, title),
      )
      .selected;

  testWidgets('Foto del recibo viene seleccionada y se puede cambiar', (
    tester,
  ) async {
    await pumpScreen(tester, const NewMovementScreen());

    expect(find.text('Recomendado'), findsOneWidget);
    expect(selected(tester, 'Foto del recibo'), isTrue);
    expect(selected(tester, 'Registro manual'), isFalse);

    await tester.tap(find.text('Registro manual'));
    await tester.pumpAndSettle();
    expect(selected(tester, 'Foto del recibo'), isFalse);
    expect(selected(tester, 'Registro manual'), isTrue);
  });

  testWidgets('sin overflow en 320 x 640 con texto al 130%', (tester) async {
    useSmallScreen(tester);
    await pumpScreen(tester, const NewMovementScreen());
    await expectNoOverflowWhileScrolling(tester);
  });
}
