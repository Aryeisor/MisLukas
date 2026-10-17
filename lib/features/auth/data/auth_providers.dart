import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../domain/entities/auth_user.dart';
import '../domain/repositories/auth_repository.dart';
import 'supabase_auth_repository.dart';

/// Repositorio de autenticación. En pruebas se sobrescribe con uno falso.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(Supabase.instance.client.auth),
);

/// Usuario con sesión; emite al iniciar o cerrar sesión.
final authStateProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Usuario actual. Mientras el stream no emite, usa la sesión ya cargada.
final currentUserProvider = Provider<AuthUser?>((ref) {
  final state = ref.watch(authStateProvider);
  return state.hasValue
      ? state.value
      : ref.watch(authRepositoryProvider).currentUser;
});
