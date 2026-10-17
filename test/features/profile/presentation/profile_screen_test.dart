import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/seed/demo_seed.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/sync/sync_controller.dart';
import 'package:mislukas/core/widgets/dev/demo_data_actions.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/auth/presentation/login_screen.dart';
import 'package:mislukas/features/profile/data/profile_providers.dart';
import 'package:mislukas/features/profile/domain/repositories/account_repository.dart';
import 'package:mislukas/features/profile/presentation/delete_account_screen.dart';
import 'package:mislukas/features/profile/presentation/profile_screen.dart';
import 'package:mislukas/features/profile/presentation/profile_view_model.dart';

import '../../../helpers/fake_account_repository.dart';
import '../../../helpers/pump_screen.dart';
import '../../../helpers/test_database.dart';
import '../../../helpers/test_session.dart';

void main() {
  Future<void> openProfile(
    WidgetTester tester,
    AppDatabase db, {
    TestSession? session,
    List<Override> overrides = const [],
  }) async {
    await pumpApp(tester, database: db, session: session, overrides: overrides);
    await loginAsDemoUser(tester);
    await openTab(tester, 'Perfil');
  }

  /// Desplaza el Perfil hasta [finder] (la lista se construye a medida que
  /// se ve) y lo toca.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ProfileScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder dialogButton(String label) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(label));

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(ProfileScreen)));

  test('initialsOf toma nombre y apellido', () {
    expect(initialsOf('Camila Rodríguez'), 'CR');
    expect(initialsOf('  ana  maría pérez '), 'AM');
    expect(initialsOf('camila'), 'C');
    expect(initialsOf(''), '');
  });

  testWidgetsWithDatabase('muestra los datos de la usuaria', (
    tester,
    db,
  ) async {
    await pumpScreen(tester, const ProfileScreen(), database: db);

    expect(find.text('CR'), findsOneWidget);
    expect(find.text('Camila Rodríguez'), findsOneWidget);
    expect(find.text('camila@ejemplo.com'), findsOneWidget);
    expect(find.text('Perfil completo en una próxima versión'), findsOneWidget);
    expect(
      find.widgetWithText(AppSecondaryButton, 'Cerrar sesión'),
      findsOneWidget,
    );
  });

  testWidgetsWithDatabase('en modo desarrollo muestra las acciones de demo', (
    tester,
    db,
  ) async {
    await pumpScreen(tester, const ProfileScreen(), database: db);

    expect(find.text('Herramientas de desarrollo'), findsOneWidget);
    expect(find.text('Cargar datos de demostración'), findsOneWidget);
    final clear = tester.widget<AppSecondaryButton>(
      find.widgetWithText(AppSecondaryButton, 'Borrar todos los datos'),
    );
    expect(clear.destructive, isTrue);
  });

  testWidgetsWithDatabase(
    'fuera de modo desarrollo no existen las acciones de demo',
    (tester, db) async {
      await pumpScreen(
        tester,
        const ProfileScreen(),
        database: db,
        overrides: [demoToolsEnabledProvider.overrideWithValue(false)],
      );

      expect(find.byType(DemoDataActions), findsNothing);
      expect(find.text('Cargar datos de demostración'), findsNothing);
      expect(find.text('Borrar todos los datos'), findsNothing);
      expect(find.text('Cerrar sesión'), findsOneWidget);
    },
  );

  testWidgetsWithDatabase('Cerrar sesión vuelve a /login', (tester, db) async {
    await openProfile(tester, db);
    expect(find.byType(ProfileScreen), findsOneWidget);

    await tapSignOut(tester);
    await tester.pumpAndSettle();
    expect(find.text('¿Cerrar sesión?'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cerrar sesión'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);
  });

  testWidgetsWithDatabase('Cancelar no cierra la sesión', (tester, db) async {
    await openProfile(tester, db);

    await tapSignOut(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgetsWithDatabase(
    'sin overflow en 320 x 640 con texto al 130%, con la barra',
    (tester, db) async {
      useSmallScreen(tester);
      await openProfile(tester, db);

      expect(find.byType(ProfileScreen), findsOneWidget);
      await expectNoOverflowWhileScrolling(tester);
      // Se llega al final de la lista.
      expect(find.text('Eliminar mi cuenta').hitTestable(), findsOneWidget);
    },
  );
  group('sincronización', () {
    testWidgetsWithDatabase(
      'la tarjeta muestra pendientes, éxito y sin conexión',
      (tester, db) async {
        final session = TestSession();
        await openProfile(tester, db, session: session);
        // La demo tiene 68 movimientos y 1 presupuesto sin enviar.
        expect(find.text('69 cambios pendientes'), findsOneWidget);

        final sync = containerOf(tester).read(syncControllerProvider.notifier);
        await pumpUntilDone(tester, sync.syncNow());
        await tester.pumpAndSettle();
        expect(
          find.text('Datos sincronizados hace un momento'),
          findsOneWidget,
        );

        session.server.offline = true;
        await pumpUntilDone(tester, sync.syncNow());
        await tester.pumpAndSettle();
        expect(find.text('Sin conexión'), findsOneWidget);
        expect(find.text(AppOfflineIndicator.message), findsOneWidget);
      },
    );

    testWidgetsWithDatabase(
      'con cambios sin enviar pide confirmar antes de cerrar sesión',
      (tester, db) async {
        final session = TestSession();
        await openProfile(tester, db, session: session);
        session.server.offline = true;

        await tapVisible(
          tester,
          find.widgetWithText(AppSecondaryButton, 'Cerrar sesión'),
        );
        await tester.tap(dialogButton('Cerrar sesión'));
        await tester.pumpAndSettle();

        expect(find.text('¿Cerrar sesión sin sincronizar?'), findsOneWidget);
        expect(find.text(unsyncedSignOutMessage(69)), findsOneWidget);

        // Cancelar conserva la sesión y los datos.
        await tester.tap(dialogButton('Cancelar'));
        await tester.pumpAndSettle();
        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(session.wiper.wipes, 0);

        // Confirmar cierra la sesión y borra lo local.
        await tapVisible(
          tester,
          find.widgetWithText(AppSecondaryButton, 'Cerrar sesión'),
        );
        await tester.tap(dialogButton('Cerrar sesión'));
        await tester.pumpAndSettle();
        await tester.tap(dialogButton('Cerrar sesión'));
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(session.wiper.wipes, 1);
      },
    );

    test('mensaje de cambios sin sincronizar en singular y plural', () {
      expect(
        unsyncedSignOutMessage(1),
        'Tienes 1 cambio sin sincronizar. Si cierras sesión ahora, se perderá.',
      );
      expect(
        unsyncedSignOutMessage(3),
        'Tienes 3 cambios sin sincronizar. Si cierras sesión ahora, se '
        'perderán.',
      );
    });
  });

  group('eliminar mi cuenta', () {
    Future<void> openDeleteAccount(WidgetTester tester) async {
      final delete = find.widgetWithText(
        AppSecondaryButton,
        'Eliminar mi cuenta',
      );
      await tapVisible(tester, delete);
      expect(find.text('¿Eliminar tu cuenta?'), findsOneWidget);
      expect(tester.widget<AppSecondaryButton>(delete).destructive, isTrue);
      await tester.tap(dialogButton('Continuar'));
      await tester.pumpAndSettle();
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
    }

    Future<void> enterPasswordAndDelete(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField), 'Clave123*');
      await tester.pump();
      await tester.tap(
        find.widgetWithText(AppSecondaryButton, 'Eliminar mi cuenta'),
      );
      await tester.pumpAndSettle();
    }

    testWidgetsWithDatabase('Cancelar en el diálogo no abre la pantalla', (
      tester,
      db,
    ) async {
      await openProfile(tester, db);
      await tapVisible(
        tester,
        find.widgetWithText(AppSecondaryButton, 'Eliminar mi cuenta'),
      );
      await tester.tap(dialogButton('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(DeleteAccountScreen), findsNothing);
    });

    testWidgetsWithDatabase(
      'con la contraseña elimina la cuenta y vuelve al login',
      (tester, db) async {
        final session = TestSession();
        final account = FakeAccountRepository();
        await openProfile(
          tester,
          db,
          session: session,
          overrides: [accountRepositoryProvider.overrideWithValue(account)],
        );
        await openDeleteAccount(tester);

        await enterPasswordAndDelete(tester);

        expect(account.calls, ['deleteStoredFiles', 'deleteAccount']);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(session.wiper.wipes, 1);
      },
    );

    testWidgetsWithDatabase(
      'si la eliminación se interrumpe permite reintentar',
      (tester, db) async {
        final account = FakeAccountRepository()
          ..deleteFailures.add(AccountDeletionFailure.network);
        await openProfile(
          tester,
          db,
          overrides: [accountRepositoryProvider.overrideWithValue(account)],
        );
        await openDeleteAccount(tester);
        await enterPasswordAndDelete(tester);

        expect(find.text('La eliminación no terminó'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        await tester.tap(find.widgetWithText(AppSecondaryButton, 'Reintentar'));
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );
  });
}

/// Toca "Cerrar sesión", que puede estar más abajo en la lista.
Future<void> tapSignOut(WidgetTester tester) async {
  final button = find.widgetWithText(AppSecondaryButton, 'Cerrar sesión');
  await tester.scrollUntilVisible(
    button,
    200,
    scrollable: find
        .descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}
