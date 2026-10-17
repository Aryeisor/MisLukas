import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/security/device_session_store.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  const storage = FlutterSecureStorage();
  const store = SecureDeviceSessionStore(storage);

  test('guarda, lee y borra el dueño de la base local', () async {
    expect(await store.readOwner(), isNull);
    await store.writeOwner('usuario-1');
    expect(await store.readOwner(), 'usuario-1');
    expect(
      await storage.read(key: SecureDeviceSessionStore.ownerKey),
      'usuario-1',
    );
    await store.clearOwner();
    expect(await store.readOwner(), isNull);
  });

  test('guarda y borra la marca de recuperación en curso', () async {
    expect(await store.readRecoveryInProgress(), isFalse);
    await store.writeRecoveryInProgress(true);
    expect(await store.readRecoveryInProgress(), isTrue);
    await store.writeRecoveryInProgress(false);
    expect(await store.readRecoveryInProgress(), isFalse);
    expect(
      await storage.containsKey(key: SecureDeviceSessionStore.recoveryKey),
      isFalse,
    );
  });
}
