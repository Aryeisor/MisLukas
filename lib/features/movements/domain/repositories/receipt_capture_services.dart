/// Permiso de cámara (docs/07 §7.9).
enum CameraPermissionStatus {
  granted,

  /// Aún se puede pedir con el diálogo del sistema.
  denied,

  /// Negado de forma permanente: solo se habilita en Ajustes.
  permanentlyDenied,

  /// Bloqueado por el sistema (control parental o perfil de trabajo).
  restricted,
}

abstract interface class CameraPermissionService {
  Future<CameraPermissionStatus> status();

  /// Muestra el diálogo del sistema si todavía se puede.
  Future<CameraPermissionStatus> request();

  /// Abre los ajustes de la app. False si no se pudieron abrir.
  Future<bool> openSettings();
}

/// Selector de fotos del sistema (docs/07 §7.2).
abstract interface class ReceiptImagePicker {
  /// Ruta de la imagen elegida, ya reducida; null si el usuario cancela.
  Future<String?> pickFromGallery();
}
