import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/app_database.dart';
import 'package:mislukas/core/theme/category_style.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/domain/entities/receipt_suggestion.dart';
import 'package:mislukas/features/movements/presentation/confirm_movement_view_model.dart';
import 'package:mislukas/features/movements/presentation/receipt/receipt_drafts.dart';

import '../../../helpers/fake_receipt_services.dart';
import '../../../helpers/test_container.dart';

/// Flujo por foto en Confirma los datos: la sugerencia del OCR llena el
/// formulario y el usuario la corrige antes de guardar (RF-17).
void main() {
  late FakeReceiptImageStore store;

  setUp(() => store = FakeReceiptImageStore());

  Future<(ProviderContainer, AppDatabase, ProviderSubscription<Object?>)> open(
    ConfirmMovementMode mode,
  ) async {
    final (container, db) = await createTestContainer(
      seed: false,
      overrides: receiptServiceOverrides(store: store),
    );
    final subscription = container.listen(
      confirmMovementViewModelProvider(mode),
      (_, _) {},
    );
    await pumpEventQueue();
    return (container, db, subscription);
  }

  ConfirmMovementState stateOf(
    ProviderContainer container,
    ConfirmMovementMode mode,
  ) => container.read(confirmMovementViewModelProvider(mode)).requireValue;

  Future<ReceiptRow> receiptOf(AppDatabase db, String movementId) => (db.select(
    db.receipts,
  )..where((t) => t.movementId.equals(movementId))).getSingle();

  test(
    'sugerencia completa: precarga valor, comercio, categoría y fecha',
    () async {
      final mode = CreatePhotoMovementMode(
        testReceiptCapture(date: DateTime(2026, 9, 20)),
      );
      final (container, _, _) = await open(mode);

      final state = stateOf(container, mode);
      expect(state.scanStatus, ReceiptScanStatus.complete);
      expect(state.amount, 87400);
      expect(state.merchant, 'Éxito');
      expect(state.category, CategoryKind.mercado);
      expect(state.date, DateTime(2026, 9, 20));
      expect(state.canSave, isTrue);
      expect(
        container.read(receiptDraftsInProgressProvider),
        contains('recibo-1'),
      );
    },
  );

  test(
    'el usuario corrige todo y guarda: el recibo conserva lo leído',
    () async {
      final mode = CreatePhotoMovementMode(testReceiptCapture());
      final (container, db, _) = await open(mode);
      final viewModel = container.read(
        confirmMovementViewModelProvider(mode).notifier,
      );

      viewModel
        ..setAmount(84000)
        ..setMerchant('Éxito Calle 80')
        ..setCategory(CategoryKind.restaurantes)
        ..setDate(DateTime(2026, 9, 19))
        ..setNote('almuerzo');
      expect(await viewModel.save(), isNull);

      final movement = await db.select(db.movements).getSingle();
      expect(movement.amount, 84000);
      expect(movement.description, 'Éxito Calle 80');
      expect(movement.categoryId, DefaultCategory.restaurantes.id);
      expect(movement.date, DateTime(2026, 9, 19));
      expect(movement.note, 'almuerzo');
      expect(movement.origin, 'foto');

      final receipt = await receiptOf(db, movement.id);
      expect(receipt.id, 'recibo-1');
      expect(receipt.localPath, 'recibos/recibo-1.enc');
      // Lo que leyó el OCR, no lo que corrigió el usuario.
      expect(receipt.detectedTotal, 87400);
      expect(receipt.detectedMerchant, 'Éxito');

      expect(container.read(receiptDraftsInProgressProvider), isEmpty);
      expect(store.deleted, isEmpty);
    },
  );

  test(
    'sugerencia parcial: el valor queda vacío y se escribe a mano',
    () async {
      final mode = CreatePhotoMovementMode(
        testReceiptCapture(status: ReceiptScanStatus.partial, total: null),
      );
      final (container, db, _) = await open(mode);
      final viewModel = container.read(
        confirmMovementViewModelProvider(mode).notifier,
      );

      expect(stateOf(container, mode).amount, isNull);
      expect(stateOf(container, mode).category, isNull);
      expect(stateOf(container, mode).canSave, isFalse);

      viewModel
        ..setAmount(15300)
        ..setCategory(CategoryKind.otros);
      expect(await viewModel.save(), isNull);

      final movement = await db.select(db.movements).getSingle();
      expect(movement.amount, 15300);
      final receipt = await receiptOf(db, movement.id);
      expect(receipt.detectedTotal, isNull);
      expect(receipt.detectedMerchant, 'Éxito');
    },
  );

  test(
    'sugerencia vacía: todo manual; sin comercio usa la categoría',
    () async {
      final mode = CreatePhotoMovementMode(
        testReceiptCapture(
          status: ReceiptScanStatus.empty,
          total: null,
          merchant: null,
        ),
      );
      final (container, db, _) = await open(mode);
      final viewModel = container.read(
        confirmMovementViewModelProvider(mode).notifier,
      );

      expect(stateOf(container, mode).merchant, isEmpty);
      viewModel
        ..setAmount(5000)
        ..setCategory(CategoryKind.transporte);
      expect(await viewModel.save(), isNull);

      final movement = await db.select(db.movements).getSingle();
      expect(movement.description, 'Transporte');
      final receipt = await receiptOf(db, movement.id);
      expect(receipt.detectedTotal, isNull);
      expect(receipt.detectedMerchant, isNull);
    },
  );

  test('una fecha sugerida futura se cambia por hoy', () async {
    final mode = CreatePhotoMovementMode(
      testReceiptCapture(date: DateTime(2026, 9, 30)),
    );
    final (container, _, _) = await open(mode);
    expect(stateOf(container, mode).date, DateTime(2026, 9, 22));
  });

  test('salir sin guardar borra la imagen cifrada y el borrador', () async {
    final mode = CreatePhotoMovementMode(testReceiptCapture());
    final (container, _, subscription) = await open(mode);

    subscription.close();
    await pumpEventQueue();

    expect(store.deleted, ['recibos/recibo-1.enc']);
    expect(container.read(receiptDraftsInProgressProvider), isEmpty);
  });
}
