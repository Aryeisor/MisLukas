import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';
import 'package:mislukas/features/movements/data/movements_providers.dart';
import 'package:mislukas/features/movements/domain/entities/receipt_suggestion.dart';
import 'package:mislukas/features/movements/domain/entities/recognized_receipt.dart';
import 'package:mislukas/features/movements/domain/repositories/receipt_capture_services.dart';
import 'package:mislukas/features/movements/domain/repositories/receipt_image_store.dart';
import 'package:mislukas/features/movements/domain/repositories/receipt_text_reader.dart';
import 'package:mislukas/features/movements/presentation/receipt/receipt_capture.dart';

// Servicios falsos del flujo de foto del recibo: sin cámara, sin ML Kit y sin
// archivos.

/// PNG de 1 x 1 píxel.
final Uint8List tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// OCR falso: devuelve [text] (una línea por renglón) o lanza si [fails].
class FakeReceiptTextReader implements ReceiptTextReader {
  FakeReceiptTextReader({this.text = '', this.fails = false});

  String text;
  bool fails;
  final List<String> readPaths = [];

  @override
  Future<RecognizedReceipt> read(String imagePath) async {
    readPaths.add(imagePath);
    if (fails) throw StateError('OCR');
    return RecognizedReceipt.fromText(text);
  }
}

/// Almacén de imágenes en memoria. Registra lo que existe sin cifrar
/// ([staged]) y cifrado ([stored]).
class FakeReceiptImageStore implements ReceiptImageStore {
  FakeReceiptImageStore({this.stageError, this.encryptError});

  /// Error de [stage] (por ejemplo, imagen muy grande).
  ReceiptImageError? stageError;

  /// Error de [encryptAndStore].
  ReceiptImageError? encryptError;

  /// Lo que devuelve [read] para cada ruta; por defecto, una imagen válida.
  final Map<String, ReceiptImage> images = {};

  /// Imágenes sin cifrar: id del recibo → ruta temporal.
  final Map<String, String> staged = {};

  /// Imágenes cifradas: ruta relativa.
  final Set<String> stored = {};

  final List<String> deleted = [];
  ({Set<String> keepPaths, Set<String> keepReceiptIds})? lastCleanUp;

  @override
  Future<String> stage(String sourcePath, {required String receiptId}) async {
    final error = stageError;
    if (error != null) throw ReceiptImageException(error);
    final path = 'tmp/$receiptId.jpg';
    staged[receiptId] = path;
    return path;
  }

  @override
  Future<void> discardStaged(String receiptId) async {
    staged.remove(receiptId);
  }

  @override
  Future<String> encryptAndStore(
    String stagedPath, {
    required String receiptId,
  }) async {
    // El temporal se borra siempre, también si falla.
    staged.remove(receiptId);
    final error = encryptError;
    if (error != null) throw ReceiptImageException(error);
    final path = 'recibos/$receiptId.enc';
    stored.add(path);
    return path;
  }

  @override
  Future<ReceiptImage> read(
    String? relativePath, {
    required String receiptId,
  }) async {
    if (relativePath == null) return const ReceiptImageNotOnDevice();
    return images[relativePath] ?? ReceiptImageAvailable(tinyPng);
  }

  @override
  Future<void> delete(String? relativePath) async {
    if (relativePath == null) return;
    deleted.add(relativePath);
    stored.remove(relativePath);
  }

  @override
  Future<void> cleanUp({
    required Set<String> keepPaths,
    required Set<String> keepReceiptIds,
  }) async {
    lastCleanUp = (keepPaths: keepPaths, keepReceiptIds: keepReceiptIds);
    stored.removeWhere(
      (path) =>
          !keepPaths.contains(path) &&
          !keepReceiptIds.any((id) => path == 'recibos/$id.enc'),
    );
    staged.removeWhere((id, _) => !keepReceiptIds.contains(id));
  }
}

/// Permiso de cámara falso: [status] es el estado actual y [onRequest] lo
/// que responde el diálogo del sistema.
class FakeCameraPermission implements CameraPermissionService {
  FakeCameraPermission({
    this.current = CameraPermissionStatus.granted,
    this.onRequest = CameraPermissionStatus.granted,
  });

  CameraPermissionStatus current;
  CameraPermissionStatus onRequest;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<CameraPermissionStatus> status() async => current;

  @override
  Future<CameraPermissionStatus> request() async {
    requests++;
    current = onRequest;
    return current;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

/// Selector de fotos falso: devuelve [path] (null = el usuario cancela).
class FakeReceiptImagePicker implements ReceiptImagePicker {
  FakeReceiptImagePicker([this.path = 'cache/galeria.jpg']);

  String? path;

  @override
  Future<String?> pickFromGallery() async => path;
}

/// Reemplaza los servicios del recibo por los falsos.
List<Override> receiptServiceOverrides({
  FakeReceiptImageStore? store,
  FakeReceiptTextReader? reader,
  FakeCameraPermission? permission,
  FakeReceiptImagePicker? picker,
}) => [
  receiptImageStoreProvider.overrideWithValue(store ?? FakeReceiptImageStore()),
  receiptTextReaderProvider.overrideWithValue(
    reader ?? FakeReceiptTextReader(),
  ),
  cameraPermissionProvider.overrideWithValue(
    permission ?? FakeCameraPermission(),
  ),
  receiptImagePickerProvider.overrideWithValue(
    picker ?? FakeReceiptImagePicker(),
  ),
];

/// Foto ya leída para abrir Confirma los datos.
ReceiptCapture testReceiptCapture({
  String receiptId = 'recibo-1',
  ReceiptScanStatus status = ReceiptScanStatus.complete,
  int? total = 87400,
  String? merchant = 'Éxito',
  DateTime? date,
  ReceiptBox? totalBox,
}) => ReceiptCapture(
  receiptId: receiptId,
  localPath: 'recibos/$receiptId.enc',
  suggestion: ReceiptSuggestion(
    status: status,
    total: total,
    merchant: merchant,
    date: date ?? DateTime(2026, 9, 22),
    category: status == ReceiptScanStatus.complete
        ? DefaultCategory.mercado
        : null,
    totalBox: totalBox,
  ),
);
