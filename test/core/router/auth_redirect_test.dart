import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/router/app_routes.dart';
import 'package:mislukas/core/router/auth_redirect.dart';

void main() {
  group('sin sesión', () {
    String? redirect(String location) =>
        authRedirect(location: location, signedIn: false);

    test('las rutas públicas se quedan', () {
      expect(redirect(AppRoutes.login), isNull);
      expect(redirect(AppRoutes.verifyEmail), isNull);
      expect(redirect(AppRoutes.recoverPassword), isNull);
    });

    test('las rutas con información financiera van a /login', () {
      for (final location in [
        AppRoutes.home,
        AppRoutes.reports,
        AppRoutes.simulator,
        AppRoutes.profile,
        AppRoutes.newMovement,
        AppRoutes.editMovementWith('abc'),
      ]) {
        expect(redirect(location), AppRoutes.login, reason: location);
      }
    });
  });

  group('con sesión', () {
    String? redirect(String location) =>
        authRedirect(location: location, signedIn: true);

    test('/login y /verify-email van a /home', () {
      expect(redirect(AppRoutes.login), AppRoutes.home);
      expect(redirect(AppRoutes.verifyEmail), AppRoutes.home);
    });

    test('/recover se mantiene para guardar la contraseña nueva', () {
      expect(redirect(AppRoutes.recoverPassword), isNull);
    });

    test('con la recuperación en curso no sale de la base /login', () {
      // La recuperación se apila sobre /login: go_router evalúa /login.
      expect(
        authRedirect(
          location: AppRoutes.login,
          signedIn: true,
          recoveryInProgress: true,
        ),
        isNull,
      );
    });

    test('la recuperación en curso no abre rutas privadas sin sesión', () {
      expect(
        authRedirect(
          location: AppRoutes.home,
          signedIn: false,
          recoveryInProgress: true,
        ),
        AppRoutes.login,
      );
    });

    test('las pantallas principales se quedan', () {
      expect(redirect(AppRoutes.home), isNull);
      expect(redirect(AppRoutes.profile), isNull);
      expect(redirect(AppRoutes.newMovement), isNull);
    });
  });
}
