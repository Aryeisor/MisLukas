import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import '../../auth/domain/auth_failure.dart';
import '../../auth/presentation/account_session_controller.dart';

/// Estado inmutable del Perfil provisional.
class ProfileState {
  const ProfileState({
    required this.fullName,
    required this.email,
    required this.initials,
    this.isSigningOut = false,
    this.signOutFailure,
    this.unsyncedOnSignOut,
  });

  final String fullName;
  final String email;

  /// Iniciales para el avatar: "CR".
  final String initials;

  final bool isSigningOut;

  /// Error al cerrar sesión; null si no hubo error.
  final AuthFailure? signOutFailure;

  /// Cambios que no se pudieron enviar antes de cerrar sesión: el usuario
  /// debe confirmar que se pierden. Null si no hay nada que confirmar.
  final int? unsyncedOnSignOut;

  ProfileState copyWith({
    bool? isSigningOut,
    AuthFailure? Function()? signOutFailure,
    int? Function()? unsyncedOnSignOut,
  }) {
    return ProfileState(
      fullName: fullName,
      email: email,
      initials: initials,
      isSigningOut: isSigningOut ?? this.isSigningOut,
      signOutFailure: signOutFailure != null
          ? signOutFailure()
          : this.signOutFailure,
      unsyncedOnSignOut: unsyncedOnSignOut != null
          ? unsyncedOnSignOut()
          : this.unsyncedOnSignOut,
    );
  }
}

final profileViewModelProvider =
    NotifierProvider<ProfileViewModel, ProfileState>(ProfileViewModel.new);

/// ViewModel del Perfil provisional: datos del usuario con sesión y cierre de
/// sesión. El perfil completo (cuenta, seguridad y preferencias) llega en una
/// próxima versión.
class ProfileViewModel extends Notifier<ProfileState> {
  @override
  ProfileState build() {
    final user = ref.watch(currentUserProvider);
    final name = user?.name ?? '';
    final email = user?.email ?? '';
    return ProfileState(
      fullName: name,
      email: email,
      // Sin nombre, la inicial del correo.
      initials: initialsOf(name.isNotEmpty ? name : email),
    );
  }

  /// Cierra la sesión conservando la sesión guardada y los datos, con
  /// "Ingresar con huella, rostro o PIN" activo (RF-13). El router vuelve al
  /// login.
  Future<void> park() async {
    if (state.isSigningOut) return;
    state = state.copyWith(
      isSigningOut: true,
      signOutFailure: () => null,
      unsyncedOnSignOut: () => null,
    );
    final outcome = await ref.read(accountActionsProvider).park();
    if (!ref.mounted) return;
    state = state.copyWith(
      isSigningOut: false,
      signOutFailure: () => switch (outcome) {
        SignOutFailed(:final failure) => failure,
        _ => null,
      },
    );
  }

  /// Borrado total: cierra la sesión y borra los datos de este dispositivo
  /// (RF-13). Antes
  /// intenta enviar los cambios pendientes; si quedan, pide confirmación
  /// ([ProfileState.unsyncedOnSignOut]) salvo con [force]. El router vuelve
  /// al login.
  Future<void> signOut({bool force = false}) async {
    if (state.isSigningOut) return;
    state = state.copyWith(
      isSigningOut: true,
      signOutFailure: () => null,
      unsyncedOnSignOut: () => null,
    );
    final outcome = await ref
        .read(accountActionsProvider)
        .signOut(force: force);
    if (!ref.mounted) return;
    state = switch (outcome) {
      SignOutDone() => state.copyWith(isSigningOut: false),
      SignOutHasPending(:final count) => state.copyWith(
        isSigningOut: false,
        unsyncedOnSignOut: () => count,
      ),
      SignOutFailed(:final failure) => state.copyWith(
        isSigningOut: false,
        signOutFailure: () => failure,
      ),
    };
  }

  /// El usuario decidió no cerrar sesión para no perder sus cambios.
  void keepSession() => state = state.copyWith(unsyncedOnSignOut: () => null);
}

/// Iniciales del primer nombre y del primer apellido, en mayúscula:
/// "Camila Rodríguez" → "CR"; "camila" → "C".
String initialsOf(String fullName) {
  final words = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  if (words.isEmpty) return '';
  final first = words.first;
  final letters = words.length > 1 ? [first, words.elementAt(1)] : [first];
  return letters
      .map((w) => String.fromCharCode(w.runes.first).toUpperCase())
      .join();
}
