import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/features/auth/data/auth_exception_mapper.dart';
import 'package:mislukas/features/auth/domain/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  AuthFailure map(String code, {String status = '400'}) =>
      mapAuthException(AuthApiException('x', statusCode: status, code: code));

  test('credenciales incorrectas: un solo error genérico (RF-06)', () {
    expect(map('invalid_credentials'), AuthFailure.invalidCredentials);
    expect(map('user_not_found'), AuthFailure.invalidCredentials);
  });

  test('429 y límites de envío: demasiados intentos', () {
    expect(map('cualquiera', status: '429'), AuthFailure.rateLimited);
    expect(map('over_request_rate_limit'), AuthFailure.rateLimited);
    expect(map('over_email_send_rate_limit'), AuthFailure.rateLimited);
  });

  test('sin conexión', () {
    expect(
      mapAuthException(AuthRetryableFetchException(message: 'SocketException')),
      AuthFailure.network,
    );
    expect(
      mapAuthException(const SocketException('sin red')),
      AuthFailure.network,
    );
    expect(mapAuthException(TimeoutException('lento')), AuthFailure.network);
  });

  test('error 5xx del servidor no se confunde con falta de conexión', () {
    expect(
      mapAuthException(AuthRetryableFetchException(statusCode: '503')),
      AuthFailure.unknown,
    );
  });

  test('códigos y contraseñas', () {
    expect(map('email_not_confirmed'), AuthFailure.emailNotConfirmed);
    expect(map('otp_expired', status: '403'), AuthFailure.invalidCode);
    expect(map('weak_password', status: '422'), AuthFailure.weakPassword);
    expect(
      mapAuthException(
        AuthWeakPasswordException(
          message: 'x',
          statusCode: '422',
          reasons: const ['length'],
        ),
      ),
      AuthFailure.weakPassword,
    );
    expect(map('same_password', status: '422'), AuthFailure.samePassword);
  });

  test('cualquier otro error es desconocido', () {
    expect(map('unexpected_failure', status: '400'), AuthFailure.unknown);
    expect(mapAuthException(StateError('x')), AuthFailure.unknown);
  });

  test('AuthFailureException conserva su error', () {
    expect(
      mapAuthException(const AuthFailureException(AuthFailure.invalidCode)),
      AuthFailure.invalidCode,
    );
  });
}
