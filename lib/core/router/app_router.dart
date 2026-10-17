import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/account_session_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/password_recovery_flow.dart';
import '../../features/auth/presentation/recover_password_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/movements/domain/entities/movement.dart';
import '../../features/movements/presentation/confirm_movement_screen.dart';
import '../../features/movements/presentation/confirm_movement_view_model.dart';
import '../../features/movements/presentation/movement_entry_method.dart';
import '../../features/movements/presentation/new_movement_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/profile/presentation/delete_account_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/simulator/presentation/simulator_screen.dart';
import '../widgets/dev/component_gallery_screen.dart';
import 'app_routes.dart';
import 'auth_redirect.dart';
import 'main_shell.dart';

/// Navegador raíz: los avisos globales (por ejemplo, datos de otra cuenta)
/// abren sus diálogos aquí, sin depender de la pantalla visible.
final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => GlobalKey<NavigatorState>(debugLabel: 'raiz'),
);

/// Router de la aplicación. El redirect decide la pantalla según la sesión
/// (docs/05 §5.1) y se vuelve a evaluar cada vez que la sesión cambia.
final appRouterProvider = Provider<GoRouter>((ref) {
  // La sesión guardada ya se cargó al iniciar Supabase: se conoce sin red.
  // Solo cuenta como sesión cuando la base local es de ese usuario: si es de
  // otro, el usuario se queda en el login hasta confirmar que se borra.
  final signedIn = ValueNotifier<bool>(
    ref.read(accountSessionProvider) == AccountSessionStatus.ready,
  );
  ref.listen(accountSessionProvider, (_, next) {
    signedIn.value = next == AccountSessionStatus.ready;
  });
  // Recuperación de contraseña en curso: con la sesión temporal no se sale
  // de la pantalla de recuperación.
  final recoveryInProgress = ValueNotifier<bool>(
    ref.read(passwordRecoveryInProgressProvider),
  );
  ref.listen(passwordRecoveryInProgressProvider, (_, next) {
    recoveryInProgress.value = next;
  });

  final router = GoRouter(
    navigatorKey: ref.read(rootNavigatorKeyProvider),
    initialLocation: AppRoutes.home,
    refreshListenable: Listenable.merge([signedIn, recoveryInProgress]),
    // Con rutas apiladas (push), go_router evalúa aquí la ruta base: desde la
    // recuperación llega /login, no /recover.
    redirect: (context, state) => authRedirect(
      location: state.matchedLocation,
      signedIn: signedIn.value,
      recoveryInProgress: recoveryInProgress.value,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        // Sin correo (por ejemplo, al reabrir la ruta) se vuelve al login.
        redirect: (context, state) =>
            state.extra is String ? null : AppRoutes.login,
        builder: (context, state) =>
            VerifyEmailScreen(email: state.extra! as String),
      ),
      GoRoute(
        path: AppRoutes.recoverPassword,
        builder: (context, state) => const RecoverPasswordScreen(),
      ),
      // Pestañas principales: cada rama conserva su estado y comparte la barra inferior.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reports,
                builder: (context, state) => const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.simulator,
                builder: (context, state) => const SimulatorScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      // Flujo de nuevo movimiento: fuera del shell, a pantalla completa sin
      // barra inferior.
      GoRoute(
        path: AppRoutes.newMovement,
        builder: (context, state) => NewMovementScreen(
          initialType:
              state.uri.queryParameters[AppRoutes.typeParam] ==
                  AppRoutes.incomeType
              ? MovementType.income
              : MovementType.expense,
        ),
      ),
      GoRoute(
        path: AppRoutes.confirmMovement,
        builder: (context, state) => ConfirmMovementScreen(
          mode: CreateMovementMode(
            MovementEntryMethod.fromName(
              state.uri.queryParameters[AppRoutes.methodParam],
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.editMovement,
        builder: (context, state) => ConfirmMovementScreen(
          mode: EditMovementMode(state.pathParameters[AppRoutes.idParam]!),
        ),
      ),
      // Se abre con push (WelcomeLauncher), encima de lo que esté visible.
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.deleteAccount,
        builder: (context, state) => const DeleteAccountScreen(),
      ),
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.devComponents,
          builder: (context, state) => const ComponentGalleryScreen(),
        ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    signedIn.dispose();
    recoveryInProgress.dispose();
  });
  return router;
});
