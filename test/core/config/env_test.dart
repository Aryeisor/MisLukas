import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/config/env.dart';

void main() {
  const url = 'https://abcd.supabase.co';
  const key = 'sb_publishable_123';

  test('acepta una URL https y una clave', () {
    expect(validateEnv(url: url, publishableKey: key), isNull);
  });

  test('falta SUPABASE_URL', () {
    final error = validateEnv(url: '', publishableKey: key);
    expect(error, contains('SUPABASE_URL'));
    expect(error, contains('--dart-define-from-file=env/dev.json'));
  });

  test('falta SUPABASE_PUBLISHABLE_KEY', () {
    final error = validateEnv(url: url, publishableKey: ' ');
    expect(error, contains('SUPABASE_PUBLISHABLE_KEY'));
  });

  test('rechaza URLs sin https (RNF-03)', () {
    for (final bad in ['http://abcd.supabase.co', 'abcd.supabase.co', 'https://']) {
      expect(
        validateEnv(url: bad, publishableKey: key),
        contains('https://'),
        reason: bad,
      );
    }
  });

  test('el mensaje nunca incluye la clave', () {
    final error = validateEnv(url: 'http://x.co', publishableKey: key);
    expect(error, isNot(contains(key)));
  });
}
