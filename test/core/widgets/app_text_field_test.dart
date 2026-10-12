import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/widgets/widgets.dart';

import '../../helpers/pump_themed.dart';

void main() {
  testWidgets('muestra la etiqueta en mayúsculas y el error', (tester) async {
    await pumpThemed(
      tester,
      const AppTextField(
        label: 'Correo electrónico',
        errorText: 'Ingresa un correo válido',
      ),
    );

    expect(find.text('CORREO ELECTRÓNICO'), findsOneWidget);
    expect(find.text('Ingresa un correo válido'), findsOneWidget);
  });

  testWidgets('el ojo alterna la visibilidad de la contraseña', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      const AppTextField(label: 'Contraseña', isPassword: true),
    );

    bool obscured() =>
        tester.widget<TextField>(find.byType(TextField)).obscureText;

    expect(obscured(), isTrue);

    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(obscured(), isFalse);

    await tester.tap(find.byTooltip('Ocultar contraseña'));
    await tester.pump();
    expect(obscured(), isTrue);
  });

  testWidgets('muestra el trailing junto a la etiqueta', (tester) async {
    await pumpThemed(
      tester,
      AppTextField(
        label: 'Contraseña',
        isPassword: true,
        trailing: TextButton(
          onPressed: () {},
          child: const Text('¿Olvidaste tu contraseña?'),
        ),
      ),
    );

    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
  });

  testWidgets('con trailing en 320 px la etiqueta cabe en una línea', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpThemed(
      tester,
      AppTextField(
        label: 'Contraseña',
        isPassword: true,
        trailing: TextButton(
          onPressed: () {},
          child: const Text('¿Olvidaste tu contraseña?'),
        ),
      ),
    );

    // Sin overflow ni otros errores de layout.
    expect(tester.takeException(), isNull);

    // La etiqueta ocupa su ancho natural: no se partió en varias líneas.
    final label = tester.renderObject<RenderParagraph>(
      find.text('CONTRASEÑA'),
    );
    expect(
      label.size.width,
      moreOrLessEquals(label.getMaxIntrinsicWidth(double.infinity)),
    );
    expect(
      label.size.height,
      moreOrLessEquals(label.getMinIntrinsicHeight(double.infinity)),
    );

    // El enlace sigue visible y dentro de la pantalla.
    final link = tester.getRect(find.text('¿Olvidaste tu contraseña?'));
    expect(link.right, lessThanOrEqualTo(320));
  });
}
