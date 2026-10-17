import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/sync/supabase_sync_remote_source.dart';
import 'package:mislukas/core/sync/sync_remote_source.dart';

void main() {
  test('los errores de red y del servidor se reintentan', () {
    for (final code in [
      null,
      '',
      '500',
      '502',
      '503',
      '504',
      '429',
      '408',
      'PGRST000',
      'PGRST003',
      '57014',
    ]) {
      expect(
        mapPostgrestCode(code),
        isA<SyncNetworkException>(),
        reason: '$code',
      );
    }
  });

  test('un JWT vencido o inválido es un error de sesión', () {
    for (final code in ['401', 'PGRST301', 'PGRST303']) {
      expect(mapPostgrestCode(code), isA<SyncAuthException>(), reason: code);
    }
  });

  test('validación, RLS y restricciones son errores del registro', () {
    for (final code in ['23514', '23503', '23505', '42501', '22P02', 'P0001']) {
      final error = mapPostgrestCode(code);
      expect(error, isA<SyncRecordException>(), reason: code);
      expect((error as SyncRecordException).code, code);
    }
  });

  test('las excepciones no incluyen datos del servidor', () {
    expect(
      const SyncRecordException('23514').toString(),
      'SyncRecordException(23514)',
    );
    expect(const SyncNetworkException().toString(), 'SyncNetworkException');
  });
}
