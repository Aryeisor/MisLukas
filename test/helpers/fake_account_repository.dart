import 'package:mislukas/features/profile/domain/repositories/account_repository.dart';

/// Servidor de eliminación de cuentas en memoria.
class FakeAccountRepository implements AccountRepository {
  final List<String> calls = [];

  /// Fallos de las siguientes llamadas a [deleteAccount], en orden.
  final List<AccountDeletionFailure> deleteFailures = [];

  @override
  Future<void> deleteStoredFiles() async => calls.add('deleteStoredFiles');

  @override
  Future<void> deleteAccount() async {
    calls.add('deleteAccount');
    if (deleteFailures.isNotEmpty) {
      throw AccountDeletionException(deleteFailures.removeAt(0));
    }
  }
}
