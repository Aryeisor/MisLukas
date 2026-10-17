import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/device_session_store.dart';
import '../domain/auth_failure.dart';
import '../domain/repositories/auth_repository.dart';

/// Hay una recuperación de contraseña en curso: el código se está verificando
/// o ya se verificó y falta guardar la contraseña nueva.
///
/// Verificar el código crea una sesión temporal. Mientras este estado es true,
/// el router deja al usuario en la pantalla de recuperación aunque haya
/// sesión, en lugar de llevarlo a Inicio.
///
/// La marca también se guarda en el almacenamiento seguro: si la app se
/// cierra con la sesión temporal, al abrirla de nuevo se cierra esa sesión
/// ([clearInterruptedRecovery]).
final passwordRecoveryInProgressProvider =
    NotifierProvider<PasswordRecoveryInProgress, bool>(
      PasswordRecoveryInProgress.new,
    );

class PasswordRecoveryInProgress extends Notifier<bool> {
  @override
  bool build() => false;

  /// Empieza la recuperación. Espera a guardar la marca, para que exista antes
  /// de que llegue la sesión temporal.
  Future<void> start() async {
    state = true;
    await _persist(true);
  }

  /// Termina la recuperación. No hace nada si el contenedor ya se cerró.
  void end() {
    if (!ref.mounted) return;
    state = false;
    _persist(false);
  }

  Future<void> _persist(bool inProgress) async {
    try {
      await ref
          .read(deviceSessionStoreProvider)
          .writeRecoveryInProgress(inProgress);
    } catch (_) {
      // Sin almacenamiento seguro la recuperación sigue igual; solo se pierde
      // la limpieza al reabrir la app.
    }
  }
}

/// Al abrir la app: si quedó una recuperación a medias (la app se cerró
/// después de verificar el código), cierra esa sesión temporal y borra la
/// marca. Se llama antes de abrir la base o sincronizar.
Future<void> clearInterruptedRecovery({
  required DeviceSessionStore store,
  required AuthRepository auth,
}) async {
  try {
    if (!await store.readRecoveryInProgress()) return;
    if (auth.currentUser != null) {
      try {
        await auth.signOut();
      } on AuthFailureException {
        // La sesión local ya se borró antes de avisar al servidor.
      }
    }
    await store.writeRecoveryInProgress(false);
  } catch (_) {
    // Sin almacenamiento seguro no hay marca que revisar.
  }
}
