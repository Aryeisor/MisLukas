import '../../../core/database/app_database.dart';
import '../domain/repositories/notification_services.dart';

/// Clave del interruptor de notificaciones en ajustes_locales.
const String notificationsSettingKey = 'notificaciones_presupuesto';

/// Clave de la marca de la explicación previa del permiso.
const String notificationsExplainedSettingKey =
    'permiso_notificaciones_explicado';

/// Ajustes de notificaciones en la base local (ajustes_locales). Se borran con
/// la base al cerrar sesión o al entrar otro usuario.
class DriftNotificationSettingsRepository
    implements NotificationSettingsRepository {
  DriftNotificationSettingsRepository(this._db);

  final AppDatabase _db;

  static const String _enabled = 'activadas';
  static const String _disabled = 'desactivadas';
  static const String _explained = 'si';

  Future<String?> _read(String key) async {
    final row = await (_db.select(
      _db.localSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _write(String key, String value) {
    return _db
        .into(_db.localSettings)
        .insertOnConflictUpdate(
          LocalSettingsCompanion.insert(key: key, value: value),
        );
  }

  @override
  Stream<bool> watchEnabled() {
    return (_db.select(_db.localSettings)
          ..where((t) => t.key.equals(notificationsSettingKey)))
        .watchSingleOrNull()
        .map((row) => row?.value != _disabled);
  }

  @override
  Future<bool> isEnabled() async =>
      await _read(notificationsSettingKey) != _disabled;

  @override
  Future<void> setEnabled(bool enabled) =>
      _write(notificationsSettingKey, enabled ? _enabled : _disabled);

  @override
  Future<bool> wasExplained() async =>
      await _read(notificationsExplainedSettingKey) == _explained;

  @override
  Future<void> markExplained() =>
      _write(notificationsExplainedSettingKey, _explained);
}
