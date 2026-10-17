import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/features/profile/data/supabase_account_repository.dart';
import 'package:mislukas/features/profile/domain/repositories/account_repository.dart';

/// Carpeta de Storage en memoria que lista como la API: de a [limit] como
/// máximo.
class FakeStoredFiles implements StoredFiles {
  FakeStoredFiles(Iterable<String> paths) : files = {...paths};

  final Set<String> files;
  int listCalls = 0;

  /// Simula una política que no deja borrar.
  bool removeHasNoEffect = false;

  @override
  Future<List<String>> list(String folder, {required int limit}) async {
    listCalls++;
    final names =
        files
            .where((path) => path.startsWith('$folder/'))
            .map((path) => path.substring(folder.length + 1))
            .toList()
          ..sort();
    return names.take(limit).toList();
  }

  @override
  Future<void> remove(List<String> paths) async {
    if (removeHasNoEffect) return;
    files.removeAll(paths);
  }
}

void main() {
  const user = '00000000-0000-4000-8000-000000000001';

  test('borra más de 100 archivos, de a una página por vez', () async {
    final files = FakeStoredFiles([
      for (var i = 0; i < 250; i++) '$user/recibo-$i.jpg',
      // De otro usuario: no se toca.
      'otro/recibo.jpg',
    ]);

    await deleteAllFiles(files, user);

    expect(files.files, {'otro/recibo.jpg'});
    // 100 + 100 + 50 y una página vacía al final.
    expect(files.listCalls, 4);
  });

  test('sin archivos no borra nada', () async {
    final files = FakeStoredFiles(const []);
    await deleteAllFiles(files, user);
    expect(files.listCalls, 1);
  });

  test('si el borrado no tiene efecto, se detiene con un error', () async {
    final files = FakeStoredFiles([for (var i = 0; i < 5; i++) '$user/$i.jpg'])
      ..removeHasNoEffect = true;

    await expectLater(
      deleteAllFiles(files, user),
      throwsA(
        isA<AccountDeletionException>().having(
          (e) => e.failure,
          'failure',
          AccountDeletionFailure.unknown,
        ),
      ),
    );
    expect(files.listCalls, 2);
  });
}
