/// Variables de entorno definidas al compilar (docs/06 §6.7.1).
///
/// Se pasan con `flutter run --dart-define-from-file=env/dev.json`. Solo
/// contienen la URL del proyecto y la clave pública (publishable) de Supabase;
/// la clave service_role nunca va en la app (docs/08 §8.5.4).
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Falla al iniciar si la configuración no es válida.
  static void ensureValid() {
    final error = validateEnv(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
    if (error != null) throw StateError(error);
  }
}

const String _runHint =
    'Ejecuta: flutter run --dart-define-from-file=env/dev.json '
    '(copia env/dev.example.json como env/dev.json y pon las claves reales).';

/// Mensaje para el desarrollador si la configuración no es válida, o null.
/// Nunca incluye el valor de la clave.
String? validateEnv({required String url, required String publishableKey}) {
  if (url.trim().isEmpty) return 'Falta SUPABASE_URL. $_runHint';
  if (publishableKey.trim().isEmpty) {
    return 'Falta SUPABASE_PUBLISHABLE_KEY. $_runHint';
  }
  final uri = Uri.tryParse(url.trim());
  // Solo HTTPS (RNF-03).
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    return 'SUPABASE_URL debe ser una URL https:// válida. $_runHint';
  }
  return null;
}
