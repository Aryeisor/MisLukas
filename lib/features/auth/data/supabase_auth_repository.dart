import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/utils/validators.dart';
import '../domain/auth_failure.dart';
import '../domain/entities/auth_user.dart';
import '../domain/repositories/auth_repository.dart';
import 'auth_exception_mapper.dart';

/// [AuthRepository] con Supabase Auth. La sesión la guarda supabase_flutter
/// en el almacenamiento seguro (core/security/secure_auth_storage.dart).
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final GoTrueClient _auth;

  /// Versión de la política de tratamiento de datos que acepta el usuario al
  /// registrarse (docs/08 §8.9.1). La tabla perfiles la registrará en 5B.
  static const String privacyPolicyVersion = '1';

  /// Clave del nombre en los metadatos del usuario (docs/06 §6.7.2).
  static const String nameMetadataKey = 'nombre';

  @override
  AuthUser? get currentUser => _toAuthUser(_auth.currentUser);

  @override
  Stream<AuthUser?> authStateChanges() {
    return Stream<AuthUser?>.multi((controller) {
      controller.add(currentUser);
      final subscription = _auth.onAuthStateChange.listen(
        (state) => controller.add(_toAuthUser(state.session?.user)),
        // Un fallo de red al renovar el token llega como error, pero la sesión
        // sigue guardada: se ignora. Si el servidor rechaza la sesión, gotrue
        // emite signedOut.
        onError: (Object _) {},
      );
      controller.onCancel = subscription.cancel;
    }).distinct();
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(
        () => _auth.signInWithPassword(
          email: normalizeEmail(email),
          password: password,
        ),
      );

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signUp(
        email: normalizeEmail(email),
        password: password,
        data: {
          nameMetadataKey: name.trim(),
          'politica_version': privacyPolicyVersion,
        },
      );
    } on AuthException catch (error) {
      // Un correo ya registrado se trata como éxito: la pantalla siempre dice
      // "Verifica tu correo" y no revela qué correos tienen cuenta.
      if (error.code == 'user_already_exists' ||
          error.code == 'email_exists') {
        return;
      }
      throw AuthFailureException(mapAuthException(error));
    } catch (error) {
      throw AuthFailureException(mapAuthException(error));
    }
  }

  @override
  Future<void> verifySignUpCode({
    required String email,
    required String code,
  }) => _guard(
    () => _auth.verifyOTP(
      email: normalizeEmail(email),
      token: code,
      type: OtpType.email,
    ),
  );

  @override
  Future<void> resendSignUpCode({required String email}) => _guard(
    () => _auth.resend(email: normalizeEmail(email), type: OtpType.signup),
  );

  @override
  Future<void> sendPasswordRecovery({required String email}) =>
      _guard(() => _auth.resetPasswordForEmail(normalizeEmail(email)));

  @override
  Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  }) => _guard(
    () => _auth.verifyOTP(
      email: normalizeEmail(email),
      token: code,
      type: OtpType.recovery,
    ),
  );

  @override
  Future<void> updatePassword({required String newPassword}) async {
    await _guard(() => _auth.updateUser(UserAttributes(password: newPassword)));
    await _signOut(SignOutScope.global);
  }

  @override
  Future<void> signOut() => _signOut(SignOutScope.local);

  /// gotrue borra la sesión local antes de avisar al servidor: si ese aviso
  /// falla por red, la sesión de este dispositivo igual quedó cerrada.
  Future<void> _signOut(SignOutScope scope) async {
    try {
      await _auth.signOut(scope: scope);
    } catch (error) {
      final failure = mapAuthException(error);
      if (failure != AuthFailure.network) throw AuthFailureException(failure);
    }
  }

  Future<void> _guard(Future<Object?> Function() action) async {
    try {
      await action();
    } catch (error) {
      throw AuthFailureException(mapAuthException(error));
    }
  }

  static AuthUser? _toAuthUser(User? user) {
    if (user == null) return null;
    final name = user.userMetadata?[nameMetadataKey];
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      name: name is String ? name : '',
    );
  }
}
