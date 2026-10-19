import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/sync/sync_controller.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/home/presentation/home_screen.dart';
import 'package:mislukas/features/movements/data/movements_providers.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/pump_screen.dart';
import '../../helpers/test_database.dart';
import '../../helpers/test_session.dart';

void main() {
  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));

  /// Avanza el tiempo simulado de a poco hasta que se cumpla [done]: Drift
  /// avanza con los frames.
  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() done, {
    Duration step = const Duration(milliseconds: 50),
    int maxSteps = 200,
  }) async {
    for (var i = 0; i < maxSteps && !done(); i++) {
      await tester.pump(step);
    }
    expect(done(), isTrue, reason: 'la condición no se cumplió a tiempo');
  }

  List<bool> pendingIcons(WidgetTester tester) => [
    for (final tile in tester.widgetList<MovementTile>(
      find.byType(MovementTile),
    ))
      tile.isPendingSync,
  ];

  testWidgetsWithDatabase(
    'sincroniza al abrir la app y 2 s después de cada escritura',
    (tester, db) async {
      final session = TestSession(autoSync: true);
      await pumpApp(
        tester,
        database: db,
        auth: FakeAuthRepository(signedInAs: testUser),
        session: session,
      );
      await pumpUntil(
        tester,
        () => session.server.rows('movimientos').length == 68,
      );

      await pumpUntilDone(
        tester,
        containerOf(tester).read(registerMovementProvider)(
          amount: 12000,
          categoryId: DefaultCategory.transporte.id,
          origin: MovementOrigin.manual,
          description: 'Bus',
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(session.server.rows('movimientos'), hasLength(68));

      await pumpUntil(
        tester,
        () => session.server.rows('movimientos').length == 69,
      );
    },
  );

  testWidgetsWithDatabase(
    'sin conexión muestra el aviso y reintenta hasta volver a tener conexión',
    (tester, db) async {
      final session = TestSession(autoSync: true);
      session.server.offline = true;
      await pumpApp(
        tester,
        database: db,
        auth: FakeAuthRepository(signedInAs: testUser),
        session: session,
      );
      await pumpUntil(
        tester,
        () => find.byType(AppOfflineIndicator).evaluate().isNotEmpty,
      );
      expect(find.text(AppOfflineIndicator.message), findsOneWidget);

      session.server.offline = false;
      // El primer reintento es a los 5 s.
      await pumpUntil(
        tester,
        () => session.server.rows('movimientos').length == 68,
        step: const Duration(milliseconds: 500),
      );
      await tester.pump();
      expect(find.byType(AppOfflineIndicator), findsNothing);
    },
  );

  testWidgetsWithDatabase(
    'los movimientos pendientes muestran el ícono y al deslizar se sincronizan',
    (tester, db) async {
      final session = TestSession();
      await pumpApp(
        tester,
        database: db,
        auth: FakeAuthRepository(signedInAs: testUser),
        session: session,
      );
      // La demo está sin enviar.
      expect(pendingIcons(tester), isNotEmpty);
      expect(pendingIcons(tester), everyElement(isTrue));

      // Deslizar hacia abajo desde arriba de la lista.
      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 300),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await pumpUntil(
        tester,
        () => session.server.rows('movimientos').length == 68,
      );
      await tester.pumpAndSettle();

      expect(pendingIcons(tester), everyElement(isFalse));
      expect(containerOf(tester).read(syncControllerProvider).pendingCount, 0);
    },
  );

  group('señal de red (connectivity_plus)', () {
    /// Sincronizaciones que llegaron al servidor (una lectura de movimientos
    /// por cada pull).
    int pulls(TestSession session) => session.server.calls
        .where((c) => c.method == 'select' && c.table == 'movimientos')
        .length;

    /// Abre la app sin red y con el servidor caído, y espera el aviso.
    Future<TestSession> openWithoutNetwork(
      WidgetTester tester,
      AppDatabase db,
    ) async {
      final session = TestSession(autoSync: true);
      session.network.available = false;
      session.server.offline = true;
      await pumpApp(
        tester,
        database: db,
        auth: FakeAuthRepository(signedInAs: testUser),
        session: session,
      );
      await pumpUntil(
        tester,
        () => find.byType(AppOfflineIndicator).evaluate().isNotEmpty,
      );
      return session;
    }

    testWidgetsWithDatabase(
      'sin red muestra el aviso de inmediato y no reintenta',
      (tester, db) async {
        final session = await openWithoutNetwork(tester, db);
        session.server.offline = false;
        // Sin red no hay reintentos con backoff (5, 10, 20, 40 s).
        await tester.pump(const Duration(seconds: 90));
        expect(pulls(session), 0);
        expect(find.byType(AppOfflineIndicator), findsOneWidget);
      },
    );

    testWidgetsWithDatabase(
      'al volver la red sincroniza en 2 s, sin esperar el backoff',
      (tester, db) async {
        final session = await openWithoutNetwork(tester, db);
        session.server.offline = false;
        await tester.pump(const Duration(seconds: 30));

        session.network.set(true);
        await tester.pump(const Duration(seconds: 1));
        expect(pulls(session), 0, reason: 'espera a que la red se estabilice');
        await pumpUntil(
          tester,
          () => session.server.rows('movimientos').length == 68,
          step: const Duration(milliseconds: 100),
          maxSteps: 30,
        );
        await tester.pump();
        expect(find.byType(AppOfflineIndicator), findsNothing);
      },
    );

    testWidgetsWithDatabase(
      'si la red parpadea, sincroniza una sola vez',
      (tester, db) async {
        final session = await openWithoutNetwork(tester, db);
        session.server.offline = false;

        for (var i = 0; i < 3; i++) {
          session.network.set(true);
          await tester.pump(const Duration(milliseconds: 500));
          session.network.set(false);
          await tester.pump(const Duration(milliseconds: 300));
        }
        session.network.set(true);
        await pumpUntil(
          tester,
          () => pulls(session) > 0,
          step: const Duration(milliseconds: 100),
          maxSteps: 30,
        );
        await tester.pump(const Duration(seconds: 10));
        // Un pull por sincronización: hubo una sola.
        expect(pulls(session), 1);
      },
    );

    testWidgetsWithDatabase(
      'con red pero sin internet el aviso se mantiene',
      (tester, db) async {
        final session = await openWithoutNetwork(tester, db);
        session.network.set(true);
        await tester.pump(const Duration(seconds: 3));
        final container = containerOf(tester);
        expect(container.read(syncControllerProvider).hasNetwork, isTrue);
        expect(
          container.read(syncControllerProvider).lastAttemptOffline,
          isTrue,
        );
        expect(find.byType(AppOfflineIndicator), findsOneWidget);

        // Con internet, el siguiente reintento (5 s) lo quita.
        session.server.offline = false;
        await pumpUntil(
          tester,
          () => find.byType(AppOfflineIndicator).evaluate().isEmpty,
          step: const Duration(milliseconds: 500),
          maxSteps: 30,
        );
      },
    );
  });

  test('la espera sin conexión crece de 5 a 60 s', () {
    expect(SyncController.offlineRetryDelay(1), const Duration(seconds: 5));
    expect(SyncController.offlineRetryDelay(2), const Duration(seconds: 10));
    expect(SyncController.offlineRetryDelay(4), const Duration(seconds: 40));
    expect(SyncController.offlineRetryDelay(5), const Duration(seconds: 60));
    expect(SyncController.offlineRetryDelay(30), const Duration(seconds: 60));
  });

  testWidgets('sin sesión no abre la base ni sincroniza', (tester) async {
    final session = TestSession(autoSync: true);
    await pumpApp(tester, session: session);
    expect(find.byType(HomeScreen), findsNothing);
    expect(session.server.calls, isEmpty);
    expect(tester.takeException(), isNull);
    // Sin base: si se hubiera abierto la real, fallaría sin path_provider.
    expect(find.byType(Scaffold), findsWidgets);
  });
}
