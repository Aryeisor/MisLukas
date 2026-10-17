import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
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

  runApp(
    ProviderScope(
      overrides: [initialLocalOwnerProvider.overrideWithValue(owner)],
      child: const MisLukasApp(),
    ),
  );
}
