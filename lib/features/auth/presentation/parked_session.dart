import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/device_session_store.dart';
import '../data/auth_providers.dart';

/// Usuario cuya sesión quedó en espera al cerrar sesión con "Ingresar con
/// huella, rostro o PIN" activo (docs/08 §8.8.4); null si no hay ninguna.
///
/// La sesión de Supabase, la base local, su clave y los recibos siguen en el
/// celular, pero la app se comporta como sin sesión ([AccountSessionStatus.
/// signedOut]) hasta que el usuario pase el diálogo del sistema desde el
/// login o escriba su contraseña.
///
/// Se guarda en el almacenamiento seguro para que un arranque en frío también
/// abra el login. La marca se compara por id: si entra otra cuenta (login,
/// registro o recuperación), deja de aplicar y se borra.
final parkedSessionProvider = NotifierProvider<ParkedSession, String?>(
  ParkedSession.new,
);

class ParkedSession extends Notifier<String?> {
  @override
  String? build() {
    ref.listen(currentUserProvider, (_, user) {
      // Otra cuenta reemplazó la sesión guardada: la marca ya no aplica.
      if (user != null && state != null && user.id != state) clear();
    });
    return ref.read(initialParkedUserProvider);
  }

  /// Deja en espera la sesión de [userId]. Espera a guardar la marca: si no
  /// se pudo, no cambia nada y devuelve false (sin marca, un arranque en frío
  /// abriría Inicio).
  Future<bool> park(String userId) async {
    try {
      await ref.read(deviceSessionStoreProvider).writeParkedUser(userId);
    } catch (_) {
      return false;
    }
    if (!ref.mounted) return false;
    state = userId;
    return true;
  }

  /// Quita la marca: el usuario volvió a entrar, o la sesión ya no existe.
  /// Si no se puede borrar del almacenamiento, el próximo arranque en frío
  /// vuelve a pedir el ingreso (falla cerrada).
  void clear() {
    if (!ref.mounted || state == null) return;
    state = null;
    ref
        .read(deviceSessionStoreProvider)
        .clearParkedUser()
        .catchError((Object _) {});
  }
}

/// Hay una sesión guardada en espera del bloqueo del celular para el usuario
/// actual: el login puede ofrecer "Ingresar con huella, rostro o PIN".
final savedSessionProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  final parked = ref.watch(parkedSessionProvider);
  return user != null && parked == user.id;
});
