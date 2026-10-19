import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/widgets/widgets.dart';
import 'package:mislukas/features/movements/domain/repositories/receipt_capture_services.dart';
import 'package:mislukas/features/movements/domain/repositories/receipt_image_store.dart';
import 'package:mislukas/features/movements/presentation/receipt/receipt_capture_screen.dart';

import '../../../../helpers/fake_receipt_services.dart';
import '../../../../helpers/pump_screen.dart';

/// Estados de la captura que no necesitan la cámara: permiso y errores.
void main() {
  Future<FakeCameraPermission> pumpCapture(
    WidgetTester tester, {
    required CameraPermissionStatus status,
    CameraPermissionStatus onRequest = CameraPermissionStatus.denied,
    FakeReceiptImageStore? store,
  }) async {
    final permission = FakeCameraPermission(
      current: status,
      onRequest: onRequest,
    );
    await pumpScreen(
      tester,
      const ReceiptCaptureScreen(),
      overrides: receiptServiceOverrides(permission: permission, store: store),
    );
    return permission;
  }

  Finder button(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate(
      (w) => w is AppPrimaryButton || w is AppSecondaryButton,
    ),
  );

  testWidgets('explicación previa: el diálogo del sistema solo al permitir', (
    tester,
  ) async {
    final permission = await pumpCapture(
      tester,
      status: CameraPermissionStatus.denied,
    );

    expect(find.text('Permite el acceso a la cámara'), findsOneWidget);
    expect(
      find.textContaining('no se comparten ni se guardan en tu galería'),
      findsOneWidget,
    );
    expect(button('Permitir cámara'), findsOneWidget);
    expect(button('Elegir de la galería'), findsOneWidget);
    expect(button('Ahora no'), findsOneWidget);
    expect(permission.requests, 0);

    await tester.tap(find.text('Permitir cámara'));
    await tester.pumpAndSettle();
    expect(permission.requests, 1);
    // Lo negó: mensaje claro con la galería y el registro manual.
    expect(find.text('No tenemos acceso a la cámara'), findsOneWidget);
    expect(button('Elegir de la galería'), findsOneWidget);
    expect(button('Registrar manual'), findsOneWidget);
  });

  testWidgets('negado permanente: cómo habilitarlo en Ajustes', (tester) async {
    final permission = await pumpCapture(
      tester,
      status: CameraPermissionStatus.permanentlyDenied,
    );

    expect(
      find.text('La cámara está desactivada para MisLukas'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Ajustes › Aplicaciones › MisLukas › Permisos'),
      findsOneWidget,
    );
    expect(button('Elegir de la galería'), findsOneWidget);
    expect(button('Registrar manual'), findsOneWidget);

    await tester.tap(find.text('Abrir Ajustes'));
    await tester.pumpAndSettle();
    expect(permission.settingsOpened, 1);
    expect(permission.requests, 0);
  });

  testWidgets('bloqueado por el sistema: galería o manual', (tester) async {
    await pumpCapture(tester, status: CameraPermissionStatus.restricted);

    expect(find.text('La cámara no está disponible'), findsOneWidget);
    expect(button('Elegir de la galería'), findsOneWidget);
    expect(find.text('Abrir Ajustes'), findsNothing);
  });

  testWidgets('imagen muy grande desde la galería: mensaje y reintento', (
    tester,
  ) async {
    await pumpCapture(
      tester,
      status: CameraPermissionStatus.permanentlyDenied,
      store: FakeReceiptImageStore(stageError: ReceiptImageError.tooLarge),
    );

    await tester.tap(find.text('Elegir de la galería'));
    await tester.pumpAndSettle();

    expect(find.text('La imagen es muy grande'), findsOneWidget);
    expect(button('Intentar de nuevo'), findsOneWidget);
    expect(button('Registrar manual'), findsOneWidget);

    await tester.tap(find.text('Intentar de nuevo'));
    await tester.pumpAndSettle();
    expect(
      find.text('La cámara está desactivada para MisLukas'),
      findsOneWidget,
    );
  });

  testWidgets('error al procesar la foto: mensaje claro', (tester) async {
    await pumpCapture(
      tester,
      status: CameraPermissionStatus.permanentlyDenied,
      store: FakeReceiptImageStore(encryptError: ReceiptImageError.failed),
    );

    await tester.tap(find.text('Elegir de la galería'));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos procesar la foto'), findsOneWidget);
  });

  testWidgets('indicación del visor: recibo solo y sobre superficie lisa', (
    tester,
  ) async {
    await pumpScreen(tester, const Center(child: ReceiptFrameHint()));
    expect(
      find.text(
        'Ubica el recibo dentro del marco, sobre una superficie lisa y sin '
        'otros papeles',
      ),
      findsOneWidget,
    );
  });

  testWidgets('pantalla pequeña sin overflow', (tester) async {
    useSmallScreen(tester);
    await pumpCapture(tester, status: CameraPermissionStatus.permanentlyDenied);
    await expectNoOverflowWhileScrolling(tester);
    expect(find.byType(ReceiptCaptureScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
