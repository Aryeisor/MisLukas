import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hay una recuperación de contraseña en curso: el código se está verificando
/// o ya se verificó y falta guardar la contraseña nueva.
///
/// Verificar el código crea una sesión temporal. Mientras este estado es true,
/// el router deja al usuario en la pantalla de recuperación aunque haya
/// sesión, en lugar de llevarlo a Inicio.
final passwordRecoveryInProgressProvider =
    NotifierProvider<PasswordRecoveryInProgress, bool>(
      PasswordRecoveryInProgress.new,
    );

class PasswordRecoveryInProgress extends Notifier<bool> {
  @override
  bool build() => false;

  void start() => state = true;

  /// Termina la recuperación. No hace nada si el contenedor ya se cerró.
  void end() {
    if (ref.mounted) state = false;
  }
}
