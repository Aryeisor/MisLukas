import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/repositories/account_repository.dart';
import 'supabase_account_repository.dart';

/// Eliminación de la cuenta. En pruebas se sobrescribe con uno falso.
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => SupabaseAccountRepository(Supabase.instance.client),
);
