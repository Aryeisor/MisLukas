import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:mislukas/core/database/app_database.dart';

/// Base Drift en memoria, sin cifrar, para probar repositorios.
AppDatabase openTestDatabase() {
  // Cada prueba abre su propia base a propósito.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}
