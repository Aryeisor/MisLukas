import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/security/secure_auth_storage.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('SecureSessionStorage', () {
    test('guarda, lee y borra la sesión en el almacenamiento seguro', () async {
      const storage = FlutterSecureStorage();
      const session = SecureSessionStorage(storage);
      await session.initialize();

      expect(await session.hasAccessToken(), isFalse);
      expect(await session.accessToken(), isNull);

      await session.persistSession('{"access_token":"x"}');
      expect(await session.hasAccessToken(), isTrue);
      expect(await session.accessToken(), '{"access_token":"x"}');
      expect(
        await storage.read(key: SecureSessionStorage.storageKey),
        '{"access_token":"x"}',
      );

      await session.removePersistedSession();
      expect(await session.hasAccessToken(), isFalse);
    });
  });

  group('SecurePkceStorage', () {
    test('guarda el verificador con prefijo propio y lo borra', () async {
      const storage = FlutterSecureStorage();
      const pkce = SecurePkceStorage(storage);

      await pkce.setItem(key: 'code-verifier', value: 'abc');
      expect(await pkce.getItem(key: 'code-verifier'), 'abc');
      expect(
        await storage.read(key: '${SecurePkceStorage.keyPrefix}code-verifier'),
        'abc',
      );

      await pkce.removeItem(key: 'code-verifier');
      expect(await pkce.getItem(key: 'code-verifier'), isNull);
    });
  });
}
