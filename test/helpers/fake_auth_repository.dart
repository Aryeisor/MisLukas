import 'dart:async';

import 'package:mislukas/features/auth/domain/auth_failure.dart';
import 'package:mislukas/features/auth/domain/entities/auth_user.dart';
import 'package:mislukas/features/auth/domain/repositories/auth_repository.dart';

/// Usuaria de las pruebas.
const AuthUser testUser = AuthUser(
  id: '00000000-0000-4000-8000-000000000001',
  email: 'camila@ejemplo.com',
  name: 'Camila Rodríguez',
);

/// [AuthRepository] en memoria, sin red. [failNext] hace fallar la siguiente
/// llamada; [calls] registra los métodos llamados.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? signedInAs, this.user = testUser})
    : _current = signedInAs;

  /// Usuario que queda con sesión al iniciar sesión o verificar un código.
  final AuthUser user;

  AuthUser? _current;
  final StreamController<AuthUser?> _changes = StreamController.broadcast();
  AuthFailure? _nextFailure;

  /// Métodos llamados, en orden.
  final List<String> calls = [];

  /// Se llama al empezar cada método, antes de responder.
  void Function(String method)? onCall;

  /// Hace fallar la siguiente llamada con [failure].
  void failNext(AuthFailure failure) => _nextFailure = failure;

  /// Emite un error en el stream, como un fallo de red al renovar el token.
  void emitStreamError() => _changes.addError(
    const AuthFailureException(AuthFailure.network),
  );

  /// Cambia la sesión desde fuera (por ejemplo, revocada en el servidor).
  void setSession(AuthUser? user) => _setCurrent(user);

  @override
  AuthUser? get currentUser => _current;

  @override
  Stream<AuthUser?> authStateChanges() {
    return Stream<AuthUser?>.multi((controller) {
      controller.add(_current);
      final subscription = _changes.stream.listen(
        controller.add,
        // Igual que el repositorio real: los errores no cierran la sesión.
        onError: (Object _) {},
      );
      controller.onCancel = subscription.cancel;
    });
  }

  Future<void> _call(String name, [void Function()? onSuccess]) async {
    calls.add(name);
    onCall?.call(name);
    await Future<void>.delayed(Duration.zero);
    final failure = _nextFailure;
    if (failure != null) {
      _nextFailure = null;
      throw AuthFailureException(failure);
    }
    onSuccess?.call();
  }

  void _setCurrent(AuthUser? user) {
    _current = user;
    _changes.add(user);
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _call('signIn', () => _setCurrent(user));

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) => _call('signUp');

  @override
  Future<void> verifySignUpCode({
    required String email,
    required String code,
  }) => _call('verifySignUpCode', () => _setCurrent(user));

  @override
  Future<void> resendSignUpCode({required String email}) =>
      _call('resendSignUpCode');

  @override
  Future<void> sendPasswordRecovery({required String email}) =>
      _call('sendPasswordRecovery');

  @override
  Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  }) => _call('verifyRecoveryCode', () => _setCurrent(user));

  @override
  Future<void> updatePassword({required String newPassword}) =>
      _call('updatePassword', () => _setCurrent(null));

  @override
  Future<void> signOut() => _call('signOut', () => _setCurrent(null));
}
