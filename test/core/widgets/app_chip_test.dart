import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/widgets/widgets.dart';

import '../../helpers/pump_themed.dart';

void main() {
  testWidgets('AppChipGroup mantiene una sola opción seleccionada', (
    tester,
  ) async {
    var selected = 'Mercado';
    await pumpThemed(
      tester,
      StatefulBuilder(
        builder: (context, setState) => AppChipGroup<String>(
          options: const ['Mercado', 'Transporte', 'Ocio'],
          selected: selected,
          labelBuilder: (option) => option,
          onSelected: (option) => setState(() => selected = option),
        ),
      ),
    );

    bool isSelected(String label) =>
        tester.widget<AppChip>(find.widgetWithText(AppChip, label)).selected;

    expect(isSelected('Mercado'), isTrue);
    expect(isSelected('Transporte'), isFalse);

    await tester.tap(find.text('Transporte'));
    await tester.pumpAndSettle();

    expect(selected, 'Transporte');
    expect(isSelected('Transporte'), isTrue);
    expect(isSelected('Mercado'), isFalse);
    expect(isSelected('Ocio'), isFalse);

    // Tocar la opción activa no la deselecciona.
    await tester.tap(find.text('Transporte'));
    await tester.pumpAndSettle();
    expect(selected, 'Transporte');
  });
}
