import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/utils_providers.dart';
import '../../data/movements_providers.dart';
import '../../domain/repositories/receipt_capture_services.dart';
import '../../domain/repositories/receipt_image_store.dart';
import 'receipt_capture.dart';
import 'receipt_drafts.dart';

/// Pasos de la captura del recibo (docs/07 §7.1, §7.2 y §7.9).
sealed class ReceiptCaptureState {
  const ReceiptCaptureState();
}

/// Revisando el permiso de cámara.
class CaptureCheckingPermission extends ReceiptCaptureState {
  const CaptureCheckingPermission();
}

/// Explicación previa al diálogo del sistema (§7.9.1). "Ahora no" vuelve sin
/// pedir el permiso.
class CaptureExplainPermission extends ReceiptCaptureState {
  const CaptureExplainPermission();
}

/// El permiso está negado: se ofrece la galería o el registro manual.
class CapturePermissionDenied extends ReceiptCaptureState {
  const CapturePermissionDenied({
    this.permanently = false,
    this.restricted = false,
  });

  /// Solo se puede habilitar en Ajustes.
  final bool permanently;

  /// El sistema no permite usar la cámara.
  final bool restricted;
}

/// La cámara está lista para tomar la foto.
class CaptureCamera extends ReceiptCaptureState {
  const CaptureCamera();
}

/// Foto tomada: "Usar foto" o "Repetir".
class CaptureReview extends ReceiptCaptureState {
  const CaptureReview(this.imagePath);

  /// Imagen temporal sin cifrar, solo para mostrarla.
  final String imagePath;
}

/// Leyendo el recibo y cifrando la imagen.
class CaptureProcessing extends ReceiptCaptureState {
  const CaptureProcessing();
}

/// La imagen no se pudo usar.
class CaptureFailed extends ReceiptCaptureState {
  const CaptureFailed(this.error);

  final ReceiptImageError error;
}

/// Lista para Confirma los datos.
class CaptureDone extends ReceiptCaptureState {
  const CaptureDone(this.capture);

  final ReceiptCapture capture;
}

final receiptCaptureViewModelProvider =
    NotifierProvider.autoDispose<ReceiptCaptureViewModel, ReceiptCaptureState>(
      ReceiptCaptureViewModel.new,
    );

/// Captura del recibo: permiso, foto o galería, OCR y cifrado.
///
/// La imagen sin cifrar solo existe entre la foto y el fin del OCR. Se borra
/// al cifrarla, al repetir, si algo falla y si el usuario sale de la
/// pantalla. El recibo queda registrado como "en curso" hasta que pasa a
/// Confirma los datos, para que la limpieza no lo borre.
class ReceiptCaptureViewModel extends Notifier<ReceiptCaptureState> {
  /// Recibo de la foto actual.
  String? _receiptId;

  /// Imagen temporal de [_receiptId].
  String? _stagedPath;

  late ReceiptImageStore _images;
  late ReceiptDraftsInProgress _drafts;

  @override
  ReceiptCaptureState build() {
    // Lo que se usa al cerrar se toma ahora: en onDispose no se usa ref.
    _images = ref.read(receiptImageStoreProvider);
    _drafts = ref.read(receiptDraftsInProgressProvider.notifier);
    ref.onDispose(_discardOnDispose);
    Future.microtask(checkPermission);
    return const CaptureCheckingPermission();
  }

  CameraPermissionService get _permission => ref.read(cameraPermissionProvider);

  /// Revisa el permiso sin pedirlo.
  Future<void> checkPermission() async {
    final status = await _permission.status();
    if (!ref.mounted) return;
    state = switch (status) {
      CameraPermissionStatus.granted => const CaptureCamera(),
      CameraPermissionStatus.denied => const CaptureExplainPermission(),
      CameraPermissionStatus.permanentlyDenied => const CapturePermissionDenied(
        permanently: true,
      ),
      CameraPermissionStatus.restricted => const CapturePermissionDenied(
        restricted: true,
      ),
    };
  }

  /// Muestra el diálogo del sistema.
  Future<void> requestPermission() async {
    final status = await _permission.request();
    if (!ref.mounted) return;
    state = switch (status) {
      CameraPermissionStatus.granted => const CaptureCamera(),
      CameraPermissionStatus.denied => const CapturePermissionDenied(),
      CameraPermissionStatus.permanentlyDenied => const CapturePermissionDenied(
        permanently: true,
      ),
      CameraPermissionStatus.restricted => const CapturePermissionDenied(
        restricted: true,
      ),
    };
  }

  /// Abre los ajustes de la app. Al volver, [onResume] revisa otra vez.
  Future<void> openSettings() => _permission.openSettings();

  /// La app volvió a primer plano: si el usuario estaba sin permiso (pudo
  /// habilitarlo en Ajustes), se revisa de nuevo.
  Future<void> onResume() async {
    if (state is CaptureExplainPermission || state is CapturePermissionDenied) {
      await checkPermission();
    }
  }

  /// La cámara tomó la foto en [path] (en la caché).
  Future<void> onPhotoTaken(String path) async {
    if (await _stage(path)) state = CaptureReview(_stagedPath!);
  }

  /// La cámara no pudo tomar la foto.
  void onCameraError() {
    _discardCurrent();
    state = const CaptureFailed(ReceiptImageError.failed);
  }

  /// Descarta la foto y vuelve a la cámara.
  Future<void> retake() async {
    _discardCurrent();
    state = const CaptureCamera();
  }

  /// Elige una foto de la galería y la procesa de inmediato.
  Future<void> pickFromGallery() async {
    final String? path;
    try {
      path = await ref.read(receiptImagePickerProvider).pickFromGallery();
    } catch (_) {
      if (ref.mounted) state = const CaptureFailed(ReceiptImageError.failed);
      return;
    }
    if (path == null || !ref.mounted) return;
    state = const CaptureProcessing();
    if (await _stage(path)) await usePhoto();
  }

  /// Lee el recibo con el OCR, cifra la imagen y borra el temporal.
  Future<void> usePhoto() async {
    final receiptId = _receiptId;
    final staged = _stagedPath;
    if (receiptId == null || staged == null) return;
    state = const CaptureProcessing();

    // El OCR corre sobre la imagen sin cifrar; nunca falla.
    final suggestion = await ref.read(scanReceiptProvider).call(staged);

    final String localPath;
    try {
      // Borra el temporal también si falla.
      localPath = await _images.encryptAndStore(staged, receiptId: receiptId);
    } on ReceiptImageException catch (error) {
      _stagedPath = null;
      _endDraft();
      if (ref.mounted) state = CaptureFailed(error.error);
      return;
    }
    _stagedPath = null;

    if (!ref.mounted) {
      // El usuario salió mientras se procesaba.
      unawaited(_images.delete(localPath));
      _endDraft();
      return;
    }
    // Desde aquí, Confirma los datos es dueña del recibo en curso.
    _receiptId = null;
    state = CaptureDone(
      ReceiptCapture(
        receiptId: receiptId,
        localPath: localPath,
        suggestion: suggestion,
      ),
    );
  }

  /// Vuelve a empezar después de un error.
  Future<void> retry() async {
    _discardCurrent();
    state = const CaptureCheckingPermission();
    await checkPermission();
  }

  /// Mueve la imagen a la carpeta temporal privada con un recibo nuevo.
  Future<bool> _stage(String sourcePath) async {
    _discardCurrent();
    final receiptId = ref.read(idGeneratorProvider).newId();
    _receiptId = receiptId;
    _drafts.add(receiptId);
    try {
      _stagedPath = await _images.stage(sourcePath, receiptId: receiptId);
      if (!ref.mounted) {
        _discardCurrent();
        return false;
      }
      return true;
    } on ReceiptImageException catch (error) {
      _endDraft();
      if (ref.mounted) state = CaptureFailed(error.error);
      return false;
    }
  }

  /// Borra la imagen temporal de la foto actual, si hay.
  void _discardCurrent() {
    final receiptId = _receiptId;
    if (receiptId == null) return;
    _stagedPath = null;
    unawaited(_images.discardStaged(receiptId));
    _endDraft();
  }

  void _endDraft() {
    final receiptId = _receiptId;
    _receiptId = null;
    if (receiptId != null) _removeDraft(receiptId);
  }

  void _removeDraft(String receiptId) {
    try {
      _drafts.remove(receiptId);
    } catch (_) {
      // El contenedor ya se cerró.
    }
  }

  /// Al salir de la pantalla sin terminar (Volver, atrás del sistema o
  /// "Ahora no"), la imagen temporal se borra.
  void _discardOnDispose() {
    final receiptId = _receiptId;
    if (receiptId == null) return;
    _receiptId = null;
    _stagedPath = null;
    unawaited(_images.discardStaged(receiptId));
    // Si el OCR seguía corriendo, usePhoto borra el archivo cifrado.
    Future.microtask(() => _removeDraft(receiptId));
  }
}
