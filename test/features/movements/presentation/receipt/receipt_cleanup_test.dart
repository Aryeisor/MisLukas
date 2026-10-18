import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/features/auth/presentation/account_session_controller.dart';
import 'package:mislukas/features/movements/data/drift_movement_repository.dart';
import 'package:mislukas/features/movements/domain/entities/movement.dart';
import 'package:mislukas/features/movements/domain/entities/receipt.dart';
import 'package:mislukas/features/movements/presentation/receipt/receipt_drafts.dart';

import '../../../../helpers/domain_fixtures.dart';
import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/fake_receipt_services.dart';
import '../../../../helpers/test_container.dart';

/// La limpieza de imágenes huérfanas corre una vez por arranque, cuando la
/// sesión queda lista, y nunca toca los recibos en curso.
void main() {
  test('con un borrador en curso, la sesión pasa a ready y su .enc sigue '
      'existiendo', () async {
    final auth = FakeAuthRepository();
    final store = FakeReceiptImageStore()
      ..stored.addAll({'recibos/en-curso.enc', 'recibos/huerfano.enc'})
      ..staged['capturando'] = 'tmp/capturando.jpg';
    final (container, _) = await createTestContainer(
      seed: false,
      auth: auth,
      overrides: receiptServiceOverrides(store: store),
    );
    container.listen(receiptCleanupProvider, (_, _) {});

    // Sin sesión no se limpia nada.
    await pumpEventQueue();
    expect(container.read(receiptCleanupProvider), 0);

    container.read(receiptDraftsInProgressProvider.notifier)
      ..add('en-curso')
      ..add('capturando');

    auth.setSession(testUser);
    await waitForState(
      container,
      accountSessionProvider,
      (s) => s == AccountSessionStatus.ready,
    );
    await waitForState(container, receiptCleanupProvider, (runs) => runs == 1);

    expect(store.stored, {'recibos/en-curso.enc'});
    expect(store.staged.keys, ['capturando']);
    expect(store.lastCleanUp!.keepReceiptIds, {'en-curso', 'capturando'});
  });

  test('conserva las imágenes de recibos guardados', () async {
    final store = FakeReceiptImageStore()
      ..stored.addAll({'recibos/r1.enc', 'recibos/huerfano.enc'});
    final (container, db) = await createTestContainer(
      seed: false,
      overrides: receiptServiceOverrides(store: store),
    );
    await DriftMovementRepository(db).add(
      testMovement(id: 'm1', origin: MovementOrigin.photo),
      receipt: const Receipt(
        id: 'r1',
        movementId: 'm1',
        localPath: 'recibos/r1.enc',
      ),
    );
    container.listen(receiptCleanupProvider, (_, _) {});

    await waitForState(container, receiptCleanupProvider, (runs) => runs == 1);
    expect(store.stored, {'recibos/r1.enc'});
  });

  test(
    'corre una sola vez por arranque, aunque la sesión vuelva a ready',
    () async {
      final auth = FakeAuthRepository(signedInAs: testUser);
      final store = FakeReceiptImageStore();
      final (container, _) = await createTestContainer(
        seed: false,
        auth: auth,
        overrides: receiptServiceOverrides(store: store),
      );
      container.listen(receiptCleanupProvider, (_, _) {});
      await waitForState(
        container,
        receiptCleanupProvider,
        (runs) => runs == 1,
      );
      expect(container.read(receiptCleanupDoneProvider), isTrue);

      // Cierre de sesión involuntario y nuevo inicio de la misma cuenta.
      store.lastCleanUp = null;
      auth.setSession(null);
      await waitForState(
        container,
        accountSessionProvider,
        (s) => s != AccountSessionStatus.ready,
      );
      auth.setSession(testUser);
      await waitForState(
        container,
        accountSessionProvider,
        (s) => s == AccountSessionStatus.ready,
      );
      await pumpEventQueue();

      expect(store.lastCleanUp, isNull);
      expect(container.read(receiptCleanupProvider), 1);
    },
  );
}
