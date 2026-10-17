import 'app_routes.dart';

/// Rutas que se pueden ver sin sesión.
const Set<String> publicRoutes = {
  AppRoutes.login,
  AppRoutes.verifyEmail,
  AppRoutes.recoverPassword,
  AppRoutes.devComponents,
};

/// Ruta a la que hay que ir según la sesión, o null para quedarse
/// (docs/05 §5.1). Función pura para el `redirect` de go_router.
///
/// - Sin sesión: solo las rutas públicas; el resto va a /login.
/// - Con sesión y [recoveryInProgress]: se queda donde está. Verificar el
///   código de recuperación crea una sesión temporal, y la pantalla de
///   recuperación (apilada sobre /login, así que go_router evalúa /login)
///   debe seguir hasta guardar la contraseña nueva.
/// - Con sesión: /login y /verify-email van a /home. /recover también se
///   mantiene.
String? authRedirect({
  required String location,
  required bool signedIn,
  bool recoveryInProgress = false,
}) {
  final isPublic = publicRoutes.contains(location);
  if (!signedIn) return isPublic ? null : AppRoutes.login;
  if (recoveryInProgress) return null;
  if (location == AppRoutes.login || location == AppRoutes.verifyEmail) {
    return AppRoutes.home;
  }
  return null;
}
