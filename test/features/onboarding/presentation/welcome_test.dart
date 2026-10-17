import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/app.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/sync/sync_controller.dart';
import 'package:mislukas/core/sync/sync_service.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/auth/presentation/password_recovery_flow.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/home/presentation/home_screen.dart';
import 'package:mislukas/features/movements/data/movements_providers.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';
import 'package:mislukas/features/onboarding/data/drift_onboarding_repository.dart';
import 'package:mislukas/features/onboarding/presentation/welcome_controller.dart';
import 'package:mislukas/features/onboarding/presentation/welcome_screen.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/pump_screen.dart';
import '../../../helpers/test_database.dart';
import '../../../helpers/test_session.dart';

void main() {
  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MisLukasApp)));

  /// Abre la app con la usuaria de pruebas con sesión y sin sincronización
  /// automática.
  Future<TestSession> openApp(
    WidgetTester tester,
    AppDatabase db, {
    TestSession? session,
  }) async {
    final testSession = session ?? TestSession();
    await pumpApp(
      tester,
      database: db,
      auth: FakeAuthRepository(signedInAs: testUser),
      session: testSession,
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    return testSession;
  }

  Future<SyncResult> sync(WidgetTester tester) async {
    final result = await pumpUntilDone(
      tester,
      containerOf(tester).read(syncControllerProvider.notifier).syncNow(),
    );
    await tester.pumpAndSettle();
    return result;
  }

  Future<bool> welcomeDone(WidgetTester tester, AppDatabase db) =>
      pumpUntilDone(tester, DriftOnboardingRepository(db).isWelcomeDone());

  Future<List<MovementRow>> incomes(WidgetTester tester, AppDatabase db) =>
      pumpUntilDone(
        tester,
        (db.select(db.movements)..where((t) => t.type.equals('ingreso'))).get(),
      );

  Finder amountInputs() => find.descendant(
    of: find.byType(AppAmountField),
    matching: find.byType(TextField),
  );

  Future<void> tapButton(WidgetTester tester, String label) async {
    final button = find.text(label);
    // Los botones de abajo siempre están; los de la lista pueden no estar
    // construidos todavía.
    if (button.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> remoteMovement(String id) => {
    'id': id,
    'categoria_id': DefaultCategory.transporte.id,
    'tipo': 'gasto',
    'monto': 5000,
    'fecha': '2026-09-21',
    'descripcion': 'Remoto',
    'nota': null,
    'origen': 'manual',
    'cuenta': 'principal',
    'creado_en': '2026-09-21T12:00:00.000Z',
    'actualizado_en': '2026-09-21T12:00:00.000Z',
    'eliminado_en': null,
  };

  group('Cuándo aparece', () {
    testWidgetsWithDatabase(
      'usuario nuevo: aparece solo después de la primera sincronización',
      (tester, db) async {
        await openApp(tester, db);
        expect(find.byType(WelcomeScreen), findsNothing);

        expect(await sync(tester), SyncResult.ok);
        expect(find.byType(WelcomeScreen), findsOneWidget);
        expect(find.text('Paso 1 de 2'), findsOneWidget);
        expect(find.text('¿Con cuánto dinero cuentas este mes?'), findsOneWidget);
        // El primer ingreso trae "Salario".
        expect(find.widgetWithText(TextField, 'Salario'), findsOneWidget);
      },
      seed: false,
    );

    testWidgetsWithDatabase(
      'sin conexión se pospone hasta una sincronización exitosa',
      (tester, db) async {
        final session = await openApp(tester, db);
        session.server.offline = true;
        expect(await sync(tester), SyncResult.offline);
        expect(find.byType(WelcomeScreen), findsNothing);

        session.server.offline = false;
        expect(await sync(tester), SyncResult.ok);
        expect(find.byType(WelcomeScreen), findsOneWidget);
      },
      seed: false,
    );

    testWidgetsWithDatabase(
      'usuario con datos en el servidor en un celular nuevo: no aparece',
      (tester, db) async {
        final session = TestSession();
        session.server.putRow(
          'movimientos',
          remoteMovement('remoto-1'),
          userId: testUser.id,
        );
        await openApp(tester, db, session: session);

        expect(await sync(tester), SyncResult.ok);
        expect(find.byType(WelcomeScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
        // Queda decidido: no sale aunque luego borre todo.
        expect(await welcomeDone(tester, db), isTrue);
      },
      seed: false,
    );

    testWidgetsWithDatabase(
      'solo con un presupuesto en el servidor tampoco aparece',
      (tester, db) async {
        final session = TestSession();
        session.server.putRow('presupuestos', {
          'id': 'p-remoto',
          'categoria_id': DefaultCategory.mercado.id,
          'mes': '2026-09-01',
          'monto_limite': 800000,
          'creado_en': '2026-09-01T12:00:00.000Z',
          'actualizado_en': '2026-09-01T12:00:00.000Z',
          'eliminado_en': null,
        }, userId: testUser.id);
        await openApp(tester, db, session: session);

        await sync(tester);
        expect(find.byType(WelcomeScreen), findsNothing);
      },
      seed: false,
    );

    testWidgetsWithDatabase(
      'si registra algo sin conexión antes de sincronizar, no aparece',
      (tester, db) async {
        final session = await openApp(tester, db);
        session.server.offline = true;
        await sync(tester);

        await pumpUntilDone(
          tester,
          containerOf(tester).read(registerIncomeProvider)(
            amount: 3800000,
            description: 'Salario',
          ),
        );
        session.server.offline = false;
        await sync(tester);

        expect(find.byType(WelcomeScreen), findsNothing);
        expect(await incomes(tester, db), hasLength(1));
      },
      seed: false,
    );

    testWidgetsWithDatabase(
      'con los datos de demostración no aparece ni duplica ingresos',
      (tester, db) async {
        await openApp(tester, db);
        await sync(tester);

        expect(find.byType(WelcomeScreen), findsNothing);
        expect(await welcomeDone(tester, db), isTrue);
        // Los 8 ingresos de la demo, sin ninguno de la bienvenida.
        expect(await incomes(tester, db), hasLength(8));
      },
    );

    testWidgetsWithDatabase(
      'no se abre durante la recuperación de contraseña',
      (tester, db) async {
        await openApp(tester, db);
        final container = containerOf(tester);
        await pumpUntilDone(
          tester,
          container.read(passwordRecoveryInProgressProvider.notifier).start(),
        );
        await tester.pumpAndSettle();

        // La sesión temporal no abre los datos: no hay sincronización.
        expect(await sync(tester), SyncResult.skipped);
        expect(find.byType(WelcomeScreen), findsNothing);
        expect(container.read(welcomeControllerProvider), WelcomeStatus.unknown);
      },
      seed: false,
    );
  });

  group('Omitir y no volver a salir', () {
    testWidgetsWithDatabase(
      'Omitir los dos pasos la marca como completada y no vuelve a salir',
      (tester, db) async {
        await openApp(tester, db);
        await sync(tester);

        await tapButton(tester, 'Omitir');
        expect(find.text('Paso 2 de 2'), findsOneWidget);
        expect(find.text('Define tus presupuestos'), findsOneWidget);
        await tapButton(tester, 'Omitir');

        expect(find.byType(WelcomeScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(await welcomeDone(tester, db), isTrue);
        expect(await incomes(tester, db), isEmpty);

        // Otra sincronización en la misma sesión.
        await sync(tester);
        expect(find.byType(WelcomeScreen), findsNothing);

        // Y al abrir la app de nuevo con la misma base.
        await tester.pumpWidget(const SizedBox.shrink());
        await openApp(tester, db);
        await sync(tester);
        expect(find.byType(WelcomeScreen), findsNothing);
      },
      seed: false,
    );

    testWidgetsWithDatabase(
      'Volver en el paso 1 también la marca como completada',
      (tester, db) async {
        await openApp(tester, db);
        await sync(tester);

        await tester.tap(find.byTooltip('Volver'));
        await tester.pumpAndSettle();

        expect(find.byType(WelcomeScreen), findsNothing);
        expect(await welcomeDone(tester, db), isTrue);
      },
      seed: false,
    );

    testWidgetsWithDatabase(
      'borrar los datos locales la reinicia',
      (tester, db) async {
        final session = await openApp(tester, db);
        await sync(tester);
        await tapButton(tester, 'Omitir');
        await tapButton(tester, 'Omitir');
        expect(await welcomeDone(tester, db), isTrue);

        await pumpUntilDone(tester, session.wiper.wipe());
        expect(await welcomeDone(tester, db), isFalse);
      },
      seed: false,
    );
  });

  group('Paso 1: ingresos', () {
    testWidgetsWithDatabase(
      'guarda los ingresos con la categoría Ingreso y no los duplica al '
      'volver',
      (tester, db) async {
        await openApp(tester, db);
        await sync(tester);

        await tester.enterText(amountInputs().first, '3800000');
        await tapButton(tester, 'Agregar otro ingreso');
        await tester.enterText(amountInputs().at(1), '450000');
        await tester.enterText(
          find
              .descendant(
                of: find.byType(AppTextField),
                matching: find.byType(TextField),
              )
              .at(1),
          'Freelance',
        );
        await tester.pump();
        await tapButton(tester, 'Continuar');
        expect(find.text('Paso 2 de 2'), findsOneWidget);

        var saved = await incomes(tester, db);
        expect(saved, hasLength(2));
        expect(
          saved.map((m) => m.categoryId).toSet(),
          {DefaultCategory.ingreso.id},
        );
        expect(
          saved.map((m) => m.description).toSet(),
          {'Salario', 'Freelance'},
        );
        expect(saved.every((m) => m.origin == 'manual'), isTrue);

        // Volver, cambiar un valor, quitar el segundo y continuar otra vez.
        await tester.tap(find.byTooltip('Volver'));
        await tester.pumpAndSettle();
        expect(find.text('Paso 1 de 2'), findsOneWidget);
        await tester.enterText(amountInputs().first, '4000000');
        // La lista arranca arriba: el segundo ingreso puede no estar a la vista.
        await tester.scrollUntilVisible(
          find.byTooltip('Quitar ingreso'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('450.000'), findsOneWidget);
        await tester.tap(find.byTooltip('Quitar ingreso'));
        await tester.pumpAndSettle();
        await tapButton(tester, 'Continuar');

        saved = await incomes(tester, db);
        final active = saved.where((m) => m.deletedAt == null).toList();
        expect(active, hasLength(1));
        expect(active.single.amount, 4000000);
        expect(saved, hasLength(2), reason: 'el quitado queda eliminado');
      },
      seed: false,
    );

    testWidgetsWithDatabase(
      'Continuar requiere un valor mayor que cero en cada ingreso',
      (tester, db) async {
        await openApp(tester, db);
        await sync(tester);

        bool canContinue() => tester
            .widget<AppPrimaryButton>(
              find.widgetWithText(AppPrimaryButton, 'Continuar'),
            )
            .onPressed !=
            null;

        expect(canContinue(), isFalse);
        await tester.enterText(amountInputs().first, '0');
        await tester.pump();
        expect(canContinue(), isFalse);
        await tester.enterText(amountInputs().first, '3800000');
        await tester.pump();
        expect(canContinue(), isTrue);
      },
      seed: false,
    );
  });

  group('Paso 2: presupuestos', () {
    testWidgetsWithDatabase(
      'crea los presupuestos del mes y termina en Inicio con el disponible',
      (tester, db) async {
        await openApp(tester, db);
        await sync(tester);

        await tester.enterText(amountInputs().first, '3800000');
        await tester.pump();
        await tapButton(tester, 'Continuar');

        // Mercado es la primera categoría.
        expect(find.text('LÍMITE MENSUAL DE MERCADO'), findsOneWidget);
        await tester.enterText(amountInputs().first, '800000');
        await tester.pump();
        await tapButton(tester, 'Guardar presupuestos');

        expect(find.byType(WelcomeScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text('\$3.800.000'), findsWidgets);
        expect(await welcomeDone(tester, db), isTrue);

        final budgets = await pumpUntilDone(
          tester,
          db.select(db.budgets).get(),
        );
        expect(budgets, hasLength(1));
        expect(budgets.single.categoryId, DefaultCategory.mercado.id);
        expect(budgets.single.limitAmount, 800000);
        expect(budgets.single.month, DateTime(2026, 9));

        // El primer gasto ya puede disparar la alerta del 75%.
        await pumpUntilDone(
          tester,
          containerOf(tester).read(registerMovementProvider)(
            amount: 600000,
            categoryId: DefaultCategory.mercado.id,
            origin: MovementOrigin.manual,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Presupuesto de mercado al 75%'), findsOneWidget);
      },
      seed: false,
    );
  });

  testWidgetsWithDatabase(
    'sin overflow en 320 x 640 con texto al 130%',
    (tester, db) async {
      useSmallScreen(tester);
      await openApp(tester, db);
      await sync(tester);
      await expectNoOverflowWhileScrolling(tester);

      await tapButton(tester, 'Omitir');
      await expectNoOverflowWhileScrolling(tester);
    },
    seed: false,
  );
}
