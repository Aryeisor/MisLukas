import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import '../../auth/domain/auth_failure.dart';

/// Estado inmutable del Perfil provisional.
class ProfileState {
  const ProfileState({
    required this.fullName,
    required this.email,
    required this.initials,
    this.isSigningOut = false,
    this.signOutFailure,
  });

  final String fullName;
  final String email;

  /// Iniciales para el avatar: "CR".
  final String initials;

  final bool isSigningOut;

  /// Error al cerrar sesión; null si no hubo error.
  final AuthFailure? signOutFailure;

  ProfileState copyWith({
    bool? isSigningOut,
    AuthFailure? Function()? signOutFailure,
  }) {
    return ProfileState(
      fullName: fullName,
      email: email,
      initials: initials,
      isSigningOut: isSigningOut ?? this.isSigningOut,
      signOutFailure: signOutFailure != null
          ? signOutFailure()
          : this.signOutFailure,
    );
  }
}

final profileViewModelProvider =
    NotifierProvider<ProfileViewModel, ProfileState>(ProfileViewModel.new);

/// ViewModel del Perfil provisional: datos del usuario con sesión y cierre de
/// sesión. El perfil completo (cuenta, seguridad, sincronización y
/// eliminación de cuenta) llega en una próxima versión.
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

  /// Cierra la sesión en este dispositivo. El router vuelve al login.
  /// Los datos locales se conservan hasta la Fase 5C.
  Future<void> signOut() async {
    if (state.isSigningOut) return;
    state = state.copyWith(isSigningOut: true, signOutFailure: () => null);
    try {
      await ref.read(authRepositoryProvider).signOut();
      if (!ref.mounted) return;
      state = state.copyWith(isSigningOut: false);
    } on AuthFailureException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isSigningOut: false,
        signOutFailure: () => error.failure,
      );
    }
  }
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
