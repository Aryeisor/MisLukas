import '../../../core/database/app_database.dart';
import '../../budgets/domain/entities/default_categories.dart';
import '../domain/onboarding_repository.dart';

/// Clave de la marca de la bienvenida en ajustes_locales.
const String welcomeSettingKey = 'bienvenida';

/// Valor de [welcomeSettingKey] cuando la bienvenida terminó.
const String welcomeDoneValue = 'completada';

/// Bienvenida en la base local (Drift). La marca vive en la base cifrada, así
/// que se borra al cerrar sesión o al entrar otro usuario.
class DriftOnboardingRepository implements OnboardingRepository {
  DriftOnboardingRepository(this._db);

  final AppDatabase _db;

  @override
  Future<bool> isWelcomeDone() async {
    final row = await (_db.select(
      _db.localSettings,
    )..where((t) => t.key.equals(welcomeSettingKey))).getSingleOrNull();
    return row?.value == welcomeDoneValue;
  }

  @override
  Future<void> markWelcomeDone() {
    return _db
        .into(_db.localSettings)
        .insertOnConflictUpdate(
          LocalSettingsCompanion.insert(
            key: welcomeSettingKey,
            value: welcomeDoneValue,
          ),
        );
  }

  // Incluye las filas eliminadas: un usuario que borró todo no es nuevo.
  @override
  Future<bool> hasOwnData() async {
    final movement =
        await (_db.selectOnly(_db.movements)
              ..addColumns([_db.movements.id])
              ..limit(1))
            .getSingleOrNull();
    if (movement != null) return true;

    final budget =
        await (_db.selectOnly(_db.budgets)
              ..addColumns([_db.budgets.id])
              ..limit(1))
            .getSingleOrNull();
    if (budget != null) return true;

    final category =
        await (_db.selectOnly(_db.categories)
              ..addColumns([_db.categories.id])
              ..where(
                _db.categories.id.isNotIn([
                  for (final c in DefaultCategory.values) c.id,
                ]),
              )
              ..limit(1))
            .getSingleOrNull();
    return category != null;
  }
}
