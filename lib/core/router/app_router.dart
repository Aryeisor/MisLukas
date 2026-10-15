import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/movements/presentation/confirm_movement_screen.dart';
import '../../features/movements/presentation/confirm_movement_view_model.dart';
import '../../features/movements/presentation/movement_entry_method.dart';
import '../../features/movements/presentation/new_movement_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/simulator/presentation/simulator_screen.dart';
import '../widgets/dev/component_gallery_screen.dart';
import 'app_routes.dart';
import 'main_shell.dart';

/// Router de la aplicación.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.login,
    // Fase 5: agregar el redirect según la sesión guardada en el almacenamiento
    // seguro: sin sesión -> /login; con sesión -> desbloqueo -> /home.
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
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
      // Flujo de nuevo gasto: fuera del shell, a pantalla completa sin barra inferior.
      GoRoute(
        path: AppRoutes.newMovement,
        builder: (context, state) => const NewMovementScreen(),
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
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.devComponents,
          builder: (context, state) => const ComponentGalleryScreen(),
        ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
