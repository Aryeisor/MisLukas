import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/notifications/local_notifications.dart';
import 'core/security/app_lock_store.dart';
import 'core/security/device_session_store.dart';
import 'core/security/secure_auth_storage.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'features/auth/presentation/password_recovery_flow.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sin URL o clave de Supabase la app no arranca (mensaje para el desarrollador).
  Env.ensureValid();

  // Carga la sesión guardada sin usar la red: la app abre sin conexión.
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      localStorage: SecureSessionStorage(),
      pkceAsyncStorage: SecurePkceStorage(),
      // Los códigos de verificación se escriben en la app: no hay deep links.
      detectSessionInUri: false,
    ),
    // Sin logs de Supabase: podrían incluir datos de la sesión (docs/08 §8.8.5).
    debug: false,
  );

  const sessionStore = SecureDeviceSessionStore();
  // Si la app se cerró a mitad de una recuperación de contraseña, la sesión
  // guardada es temporal: se cierra antes de abrir la base o sincronizar.
  await clearInterruptedRecovery(
    store: sessionStore,
    auth: SupabaseAuthRepository(Supabase.instance.client.auth),
  );
  // Dueño de la base local, para decidir la pantalla inicial sin esperar.
  final owner = await sessionStore.readOwner().catchError((Object _) => null);
  // Sesión en espera del bloqueo del celular: se abre el login. Si no se puede
  // leer la marca, se trata la sesión actual como en espera (falla cerrada:
  // se entra con el bloqueo del celular o la contraseña).
  final parkedUser = await sessionStore.readParkedUser().catchError(
    (Object _) => Supabase.instance.client.auth.currentUser?.id,
  );
  // Bloqueo con el bloqueo del celular: se decide antes de mostrar nada.
  final appLockEnabled = await const SecureAppLockStore()
      .readEnabled()
      .catchError((Object _) => false);

  // Antes de runApp para saber si una notificación abrió la app. No pide el
  // permiso: se pide al crear el primer presupuesto (docs/07 §7.9).
  final notifications = LocalNotifications();
  await notifications.initialize();

  runApp(
    ProviderScope(
      overrides: [
        initialLocalOwnerProvider.overrideWithValue(owner),
        initialParkedUserProvider.overrideWithValue(parkedUser),
        initialAppLockEnabledProvider.overrideWithValue(appLockEnabled),
        localNotificationsProvider.overrideWithValue(notifications),
      ],
      child: const MisLukasApp(),
    ),
  );
}
