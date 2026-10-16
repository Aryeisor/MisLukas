import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_failure.dart';

/// Traduce un error de Supabase Auth a [AuthFailure]. El mensaje del servidor
/// nunca llega al usuario.
AuthFailure mapAuthException(Object error) {
  if (error is AuthFailureException) return error.failure;
  if (error is SocketException || error is TimeoutException) {
    return AuthFailure.network;
  }
  if (error is! AuthException) return AuthFailure.unknown;

  // Límite de solicitudes (429), por IP o por cuenta.
  if (error.statusCode == '429' ||
      error.code == 'over_request_rate_limit' ||
      error.code == 'over_email_send_rate_limit') {
    return AuthFailure.rateLimited;
  }
  if (error is AuthRetryableFetchException) {
    // Sin código HTTP la solicitud no llegó al servidor; con 5xx el servidor
    // falló.
    final status = int.tryParse(error.statusCode ?? '');
    return status != null && status >= 500
        ? AuthFailure.unknown
        : AuthFailure.network;
  }
  if (error is AuthWeakPasswordException) return AuthFailure.weakPassword;

  return switch (error.code) {
    'invalid_credentials' || 'user_not_found' => AuthFailure.invalidCredentials,
    'email_not_confirmed' => AuthFailure.emailNotConfirmed,
    'otp_expired' || 'otp_disabled' => AuthFailure.invalidCode,
    'weak_password' => AuthFailure.weakPassword,
    'same_password' => AuthFailure.samePassword,
    _ => AuthFailure.unknown,
  };
}
