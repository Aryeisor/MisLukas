import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/home/presentation/home_screen.dart';

import 'helpers/pump_screen.dart';

void main() {
  testWidgets(
    'flujo completo: login → inicio → nuevo gasto → confirmar → inicio',
    (tester) async {
      await pumpApp(tester);
      await loginAsDemoUser(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('\$2.375.680'), findsOneWidget);

      // Nuevo gasto con registro manual.
      await tester.tap(find.text('Nuevo gasto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registro manual'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Registra tu gasto'), findsOneWidget);

      // Valor, categoría y nota.
      await tester.enterText(
        find.descendant(
          of: find.byType(AppAmountField),
          matching: find.byType(TextField),
        ),
        '25000',
      );
      await tester.tap(find.text('Transporte'));
      await tester.pumpAndSettle();
      final noteField = find.descendant(
        of: find.ancestor(
          of: find.text('NOTA (OPCIONAL)'),
          matching: find.byType(AppTextField),
        ),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(noteField);
      await tester.enterText(noteField, 'Taxi');
      await tester.pump();

      await tester.tap(find.widgetWithText(AppPrimaryButton, 'Guardar gasto'));
      await tester.pumpAndSettle();

      // De vuelta en Inicio con el movimiento nuevo arriba.
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(AppBottomNav), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Gasto guardado'),
        ),
        findsOneWidget,
      );

      final firstTile = tester.widget<MovementTile>(
        find.byType(MovementTile).first,
      );
      expect(firstTile.title, 'Taxi');
      expect(firstTile.amount, 25000);
      expect(firstTile.dateLabel, 'Hoy');

      // Los gastos suben y el disponible baja.
      expect(find.text('\$2.400.680'), findsOneWidget);
      expect(find.text('\$1.849.320'), findsOneWidget);
    },
  );
}
