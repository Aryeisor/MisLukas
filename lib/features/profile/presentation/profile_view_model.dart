import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_data.dart';

/// Estado inmutable del Perfil provisional.
class ProfileState {
  const ProfileState({
    required this.fullName,
    required this.email,
    required this.initials,
  });

  final String fullName;
  final String email;

  /// Iniciales para el avatar: "CR".
  final String initials;
}

final profileViewModelProvider =
    NotifierProvider<ProfileViewModel, ProfileState>(ProfileViewModel.new);

/// ViewModel del Perfil provisional. El perfil completo (cuenta, seguridad,
/// sincronización y eliminación de cuenta) llega en una próxima versión.
class ProfileViewModel extends Notifier<ProfileState> {
  @override
  ProfileState build() {
    return ProfileState(
      fullName: demoUserFullName,
      email: demoUserEmail,
      initials: initialsOf(demoUserFullName),
    );
  }
}

/// Iniciales del primer nombre y del primer apellido, en mayúscula:
/// "Camila Rodríguez" → "CR"; "camila" → "C".
String initialsOf(String fullName) {
  final words = fullName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '';
  final first = words.first;
  final letters = words.length > 1 ? [first, words.elementAt(1)] : [first];
  return letters
      .map((w) => String.fromCharCode(w.runes.first).toUpperCase())
      .join();
}
