import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/features/movements/domain/entities/receipt_suggestion.dart';
import 'package:mislukas/features/movements/domain/repositories/receipt_capture_services.dart';
import 'package:mislukas/features/movements/domain/repositories/receipt_image_store.dart';
import 'package:mislukas/features/movements/presentation/receipt/receipt_capture_view_model.dart';
import 'package:mislukas/features/movements/presentation/receipt/receipt_drafts.dart';

import '../../../../helpers/fake_receipt_services.dart';
import '../../../../helpers/test_container.dart';

const _fullReceipt = '''
ALMACENES EXITO S.A.
NIT 890.900.608-9
FECHA 20/09/2026
SUBTOTAL 73.445
IVA 13.955
TOTAL A PAGAR \$87.400
''';

void main() {
  late FakeCameraPermission permission;
  late FakeReceiptImageStore store;
  late FakeReceiptTextReader reader;
  late FakeReceiptImagePicker picker;

  setUp(() {
    permission = FakeCameraPermission();
    store = FakeReceiptImageStore();
    reader = FakeReceiptTextReader(text: _fullReceipt);
    picker = FakeReceiptImagePicker();
  });

  /// Contenedor con la captura abierta (escuchada) y el permiso revisado.
  Future<(ProviderContainer, ProviderSubscription<ReceiptCaptureState>)>
  open() async {
    final (container, _) = await createTestContainer(
      seed: false,
      overrides: receiptServiceOverrides(
        store: store,
        reader: reader,
        permission: permission,
        picker: picker,
      ),
    );
    final subscription = container.listen(
      receiptCaptureViewModelProvider,
      (_, _) {},
    );
    await pumpEventQueue();
    return (container, subscription);
  }

  ReceiptCaptureViewModel viewModel(ProviderContainer container) =>
      container.read(receiptCaptureViewModelProvider.notifier);

  ReceiptCaptureState stateOf(ProviderContainer container) =>
      container.read(receiptCaptureViewModelProvider);

  group('Permiso de cámara', () {
    test('concedido: abre la cámara sin pedir nada', () async {
      final (container, _) = await open();
      expect(stateOf(container), isA<CaptureCamera>());
      expect(permission.requests, 0);
    });

    test('sin pedir todavía: explicación previa y luego el diálogo', () async {
      permission.current = CameraPermissionStatus.denied;
      final (container, _) = await open();
      expect(stateOf(container), isA<CaptureExplainPermission>());
      expect(permission.requests, 0);

      await viewModel(container).requestPermission();
      expect(permission.requests, 1);
      expect(stateOf(container), isA<CaptureCamera>());
    });

    test('"Ahora no" sale sin mostrar el diálogo del sistema', () async {
      permission.current = CameraPermissionStatus.denied;
      final (container, subscription) = await open();
      expect(stateOf(container), isA<CaptureExplainPermission>());

      subscription.close();
      await pumpEventQueue();
      expect(permission.requests, 0);
    });

    test('negado: ofrece galería o manual y se puede volver a pedir', () async {
      permission
        ..current = CameraPermissionStatus.denied
        ..onRequest = CameraPermissionStatus.denied;
      final (container, _) = await open();
      await viewModel(container).requestPermission();

      final state = stateOf(container);
      expect(state, isA<CapturePermissionDenied>());
      expect((state as CapturePermissionDenied).permanently, isFalse);
    });

    test(
      'negado permanente: Ajustes, y al volver se revisa otra vez',
      () async {
        permission
          ..current = CameraPermissionStatus.denied
          ..onRequest = CameraPermissionStatus.permanentlyDenied;
        final (container, _) = await open();
        await viewModel(container).requestPermission();

        final state = stateOf(container);
        expect((state as CapturePermissionDenied).permanently, isTrue);

        await viewModel(container).openSettings();
        expect(permission.settingsOpened, 1);

        // El usuario lo activó en Ajustes y volvió a la app.
        permission.current = CameraPermissionStatus.granted;
        await viewModel(container).onResume();
        expect(stateOf(container), isA<CaptureCamera>());
      },
    );

    test('negado permanente desde antes: se muestra al abrir', () async {
      permission.current = CameraPermissionStatus.permanentlyDenied;
      final (container, _) = await open();
      final state = stateOf(container) as CapturePermissionDenied;
      expect(state.permanently, isTrue);
      expect(permission.requests, 0);
    });

    test('bloqueado por el sistema', () async {
      permission.current = CameraPermissionStatus.restricted;
      final (container, _) = await open();
      final state = stateOf(container) as CapturePermissionDenied;
      expect(state.restricted, isTrue);
    });

    test('volver a primer plano no interrumpe la cámara', () async {
      final (container, _) = await open();
      await viewModel(container).onPhotoTaken('cache/CAP1.jpg');
      await viewModel(container).onResume();
      expect(stateOf(container), isA<CaptureReview>());
    });
  });

  group('Foto con la cámara', () {
    test('tomar, revisar y usar: sugerencia completa y sin temporal', () async {
      final (container, _) = await open();
      await viewModel(container).onPhotoTaken('cache/CAP1.jpg');

      expect(stateOf(container), isA<CaptureReview>());
      final drafts = container.read(receiptDraftsInProgressProvider);
      expect(drafts, hasLength(1));
      final receiptId = drafts.single;
      expect(store.staged.keys, [receiptId]);

      await viewModel(container).usePhoto();

      final done = stateOf(container) as CaptureDone;
      expect(done.capture.receiptId, receiptId);
      expect(done.capture.localPath, 'recibos/$receiptId.enc');
      expect(done.capture.suggestion.status, ReceiptScanStatus.complete);
      expect(done.capture.suggestion.total, 87400);
      expect(done.capture.suggestion.merchant, 'Éxito');
      expect(done.capture.suggestion.date, DateTime(2026, 9, 20));
      // El OCR leyó el temporal; después se borró.
      expect(reader.readPaths, ['tmp/$receiptId.jpg']);
      expect(store.staged, isEmpty);
      expect(store.stored, {'recibos/$receiptId.enc'});
      // Sigue en curso hasta que Confirma los datos lo guarde o lo descarte.
      expect(container.read(receiptDraftsInProgressProvider), {receiptId});
    });

    test('sugerencia parcial: se leyó el recibo, pero no el total', () async {
      reader.text = 'TIENDA LA ESQUINA\nARROZ 3.200\nGRACIAS';
      final (container, _) = await open();
      await viewModel(container).onPhotoTaken('cache/CAP1.jpg');
      await viewModel(container).usePhoto();

      final done = stateOf(container) as CaptureDone;
      expect(done.capture.suggestion.status, ReceiptScanStatus.partial);
      expect(done.capture.suggestion.total, isNull);
      expect(done.capture.suggestion.merchant, 'Tienda la Esquina');
    });

    test('error al leer: sugerencia vacía y el temporal se borra', () async {
      reader.fails = true;
      final (container, _) = await open();
      await viewModel(container).onPhotoTaken('cache/CAP1.jpg');
      await viewModel(container).usePhoto();

      final done = stateOf(container) as CaptureDone;
      expect(done.capture.suggestion.status, ReceiptScanStatus.empty);
      expect(done.capture.suggestion.date, DateTime(2026, 9, 22));
      expect(store.staged, isEmpty);
    });

    test('repetir descarta la foto y vuelve a la cámara', () async {
      final (container, _) = await open();
      await viewModel(container).onPhotoTaken('cache/CAP1.jpg');
      await viewModel(container).retake();
      await pumpEventQueue();

      expect(stateOf(container), isA<CaptureCamera>());
      expect(store.staged, isEmpty);
      expect(container.read(receiptDraftsInProgressProvider), isEmpty);
    });

    test('si falla el cifrado: error, sin temporal y sin borrador', () async {
      store.encryptError = ReceiptImageError.failed;
      final (container, _) = await open();
      await viewModel(container).onPhotoTaken('cache/CAP1.jpg');
      await viewModel(container).usePhoto();

      expect(stateOf(container), isA<CaptureFailed>());
      expect(store.staged, isEmpty);
      expect(store.stored, isEmpty);
      expect(container.read(receiptDraftsInProgressProvider), isEmpty);
    });

    test('la cámara falla: error con opción de reintentar', () async {
      final (container, _) = await open();
      viewModel(container).onCameraError();
      expect(stateOf(container), isA<CaptureFailed>());

      await viewModel(container).retry();
      expect(stateOf(container), isA<CaptureCamera>());
    });

    test('salir durante la revisión borra la imagen temporal', () async {
      final (container, subscription) = await open();
      await viewModel(container).onPhotoTaken('cache/CAP1.jpg');
      expect(store.staged, hasLength(1));

      subscription.close();
      await pumpEventQueue();

      expect(store.staged, isEmpty);
      expect(container.read(receiptDraftsInProgressProvider), isEmpty);
    });
  });

  group('Galería', () {
    test('elegir una foto la procesa sin revisión', () async {
      permission.current = CameraPermissionStatus.permanentlyDenied;
      final (container, _) = await open();
      await viewModel(container).pickFromGallery();

      final done = stateOf(container) as CaptureDone;
      expect(done.capture.suggestion.total, 87400);
      expect(store.staged, isEmpty);
    });

    test('cancelar el selector no cambia nada', () async {
      picker.path = null;
      permission.current = CameraPermissionStatus.denied;
      final (container, _) = await open();
      await viewModel(container).pickFromGallery();

      expect(stateOf(container), isA<CaptureExplainPermission>());
      expect(container.read(receiptDraftsInProgressProvider), isEmpty);
    });

    test('imagen muy grande: error y sin borrador', () async {
      store.stageError = ReceiptImageError.tooLarge;
      final (container, _) = await open();
      await viewModel(container).pickFromGallery();

      final state = stateOf(container) as CaptureFailed;
      expect(state.error, ReceiptImageError.tooLarge);
      expect(container.read(receiptDraftsInProgressProvider), isEmpty);
      expect(reader.readPaths, isEmpty);
    });
  });
}
