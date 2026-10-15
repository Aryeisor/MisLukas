import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/database_providers.dart';
import 'package:mislukas/core/utils/utils_providers.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/home/presentation/home_screen.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/pump_screen.dart';
import '../../../helpers/test_database.dart';

void main() {
  testWidgetsWithDatabase('muestra disponible, alerta y últimos movimientos', (
    tester,
    db,
  ) async {
    await pumpScreen(tester, const HomeScreen(), database: db);

    expect(find.text('Septiembre 2026'), findsOneWidget);
    expect(find.text('Hola, Camila 👋'), findsOneWidget);
    expect(find.text('\$1.874.320'), findsOneWidget);
    expect(find.text('\$4.250.000'), findsOneWidget);
    expect(find.text('\$2.375.680'), findsOneWidget);
    expect(find.text('Presupuesto de mercado al 78%'), findsOneWidget);
    expect(find.text('Te quedan \$253.000 para fin de mes'), findsOneWidget);
    expect(find.text('Últimos movimientos'), findsOneWidget);
    expect(find.byTooltip('Notificaciones'), findsOneWidget);
    expect(
      find.widgetWithText(AppPrimaryButton, 'Nuevo gasto'),
      findsOneWidget,
    );

    final tiles = tester
        .widgetList<MovementTile>(find.byType(MovementTile))
        .toList();
    expect(tiles.first.title, 'Éxito');
    expect(tiles.first.dateLabel, 'Hoy');
    expect(tiles[1].title, 'TransMilenio');
    expect(tiles[1].dateLabel, 'Ayer');
  });

  testWidgetsWithDatabase('estado vacío sin movimientos', (tester, db) async {
    await pumpScreen(tester, const HomeScreen(), database: db);

    expect(find.text('Aún no tienes movimientos este mes'), findsOneWidget);
    expect(find.byType(MovementTile), findsNothing);
  }, seed: false);

  testWidgetsWithDatabase('sin presupuestos no hay alerta', (tester, db) async {
    await db.delete(db.budgets).go();
    await pumpScreen(tester, const HomeScreen(), database: db);

    expect(find.text('\$2.375.680'), findsOneWidget);
    expect(find.textContaining('Presupuesto de'), findsNothing);
  });

  testWidgetsWithDatabase(
    'si la base no abre muestra un error en lugar de cerrarse',
    (tester, db) async {
      await pumpScreen(
        tester,
        const HomeScreen(),
        overrides: [
          clockProvider.overrideWithValue(testClock),
          appDatabaseProvider.overrideWith(
            (ref) => throw StateError('Falta la clave'),
          ),
        ],
      );

      expect(find.text('No pudimos cargar tu información'), findsOneWidget);
      expect(
        find.text(
          'No pudimos abrir tus datos guardados. Cierra y vuelve a abrir la app.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
    seed: false,
  );

  testWidgetsWithDatabase(
    'sin overflow en 320 x 640 con texto al 130%, con la barra',
    (tester, db) async {
      useSmallScreen(tester);
      await pumpApp(tester, database: db);
      await loginAsDemoUser(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(AppBottomNav), findsOneWidget);
      await expectNoOverflowWhileScrolling(tester);
    },
  );
}
