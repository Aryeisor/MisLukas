import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/database_providers.dart';
import '../utils/utils_providers.dart';
import 'local_sync_store.dart';
import 'supabase_sync_remote_source.dart';
import 'sync_remote_source.dart';
import 'sync_service.dart';

/// Fuente remota. En pruebas se sobrescribe con un servidor en memoria.
final syncRemoteSourceProvider = Provider<SyncRemoteSource>(
  (ref) => SupabaseSyncRemoteSource(Supabase.instance.client),
);

/// Acceso local de la sincronización sobre la base actual.
final localSyncStoreProvider = Provider<LocalSyncStore>(
  (ref) => LocalSyncStore(ref.watch(appDatabaseProvider)),
);

/// Servicio de sincronización. Se recrea con la base: al borrar los datos
/// locales, el anterior se detiene.
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    store: ref.watch(localSyncStoreProvider),
    remote: ref.watch(syncRemoteSourceProvider),
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(service.shutdown);
  return service;
});

/// Sincronizar solo (al abrir, después de escribir, cada cierto tiempo y al
/// recuperar la conexión). Las pruebas lo apagan y sincronizan a mano.
final syncAutoTriggersProvider = Provider<bool>((ref) => true);
