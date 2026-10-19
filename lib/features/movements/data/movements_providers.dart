import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/security/external_activity_tracker.dart';
import '../../../core/utils/utils_providers.dart';
import '../../budgets/data/budgets_providers.dart';
import '../domain/repositories/movement_repository.dart';
import '../domain/repositories/receipt_capture_services.dart';
import '../domain/repositories/receipt_cipher.dart';
import '../domain/repositories/receipt_image_store.dart';
import '../domain/repositories/receipt_text_reader.dart';
import '../domain/usecases/clean_receipt_images.dart';
import '../domain/usecases/delete_movement.dart';
import '../domain/usecases/get_movement.dart';
import '../domain/usecases/register_income.dart';
import '../domain/usecases/register_movement.dart';
import '../domain/usecases/scan_receipt.dart';
import '../domain/usecases/update_movement.dart';
import '../domain/usecases/watch_month_summary.dart';
import '../domain/usecases/watch_movement_history.dart';
import '../domain/usecases/watch_recent_movements.dart';
import 'drift_movement_repository.dart';
import 'receipts/aes_gcm_receipt_cipher.dart';
import 'receipts/device_receipt_capture_services.dart';
import 'receipts/file_receipt_image_store.dart';
import 'receipts/ml_kit_receipt_text_reader.dart';

final movementRepositoryProvider = Provider<MovementRepository>(
  (ref) => DriftMovementRepository(ref.watch(appDatabaseProvider)),
);

final registerMovementProvider = Provider<RegisterMovement>(
  (ref) => RegisterMovement(
    movements: ref.watch(movementRepositoryProvider),
    categories: ref.watch(categoryRepositoryProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
  ),
);

final registerIncomeProvider = Provider<RegisterIncome>(
  (ref) => RegisterIncome(ref.watch(registerMovementProvider)),
);

final updateMovementProvider = Provider<UpdateMovement>(
  (ref) => UpdateMovement(
    movements: ref.watch(movementRepositoryProvider),
    categories: ref.watch(categoryRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final deleteMovementProvider = Provider<DeleteMovement>(
  (ref) => DeleteMovement(
    movements: ref.watch(movementRepositoryProvider),
    clock: ref.watch(clockProvider),
    images: ref.watch(receiptImageStoreProvider),
  ),
);

final getMovementProvider = Provider<GetMovement>(
  (ref) => GetMovement(movements: ref.watch(movementRepositoryProvider)),
);

final watchRecentMovementsProvider = Provider<WatchRecentMovements>(
  (ref) =>
      WatchRecentMovements(movements: ref.watch(movementRepositoryProvider)),
);

final watchMovementHistoryProvider = Provider<WatchMovementHistory>(
  (ref) =>
      WatchMovementHistory(movements: ref.watch(movementRepositoryProvider)),
);

final watchMonthSummaryProvider = Provider<WatchMonthSummary>(
  (ref) => WatchMonthSummary(
    movements: ref.watch(movementRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

// Foto del recibo (Fase 6A)

/// Cifrado AES-GCM de las imágenes con la clave de recibos.
final receiptCipherProvider = Provider<ReceiptCipher>(
  (ref) => AesGcmReceiptCipher(ref.watch(receiptKeyStoreProvider)),
);

/// Imágenes de recibos cifradas en el almacenamiento privado de la app.
final receiptImageStoreProvider = Provider<ReceiptImageStore>(
  (ref) => FileReceiptImageStore(
    directory: getApplicationSupportDirectory,
    cacheDirectory: getTemporaryDirectory,
    cipher: ref.watch(receiptCipherProvider),
  ),
);

/// OCR en el dispositivo. El modelo se libera con el contenedor.
final receiptTextReaderProvider = Provider<ReceiptTextReader>((ref) {
  final reader = MlKitReceiptTextReader();
  ref.onDispose(reader.close);
  return reader;
});

final cameraPermissionProvider = Provider<CameraPermissionService>(
  (ref) => PermissionHandlerCameraPermission(
    ref.read(externalActivityTrackerProvider),
  ),
);

final receiptImagePickerProvider = Provider<ReceiptImagePicker>(
  (ref) => ImagePickerReceiptPicker(ref.read(externalActivityTrackerProvider)),
);

final scanReceiptProvider = Provider<ScanReceipt>(
  (ref) => ScanReceipt(
    reader: ref.watch(receiptTextReaderProvider),
    clock: ref.watch(clockProvider),
  ),
);

final cleanReceiptImagesProvider = Provider<CleanReceiptImages>(
  (ref) => CleanReceiptImages(
    movements: ref.watch(movementRepositoryProvider),
    images: ref.watch(receiptImageStoreProvider),
  ),
);
