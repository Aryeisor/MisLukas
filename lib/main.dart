import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/security/secure_auth_storage.dart';

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

  runApp(const ProviderScope(child: MisLukasApp()));
}
