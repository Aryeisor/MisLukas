import '../database/sql_converters.dart';

// Lectura y escritura de valores en el JSON de Supabase (PostgREST) para los
// DTOs remotos (docs/06 §6.4.3). Los errores nombran solo la columna, nunca
// el valor: puede ser un monto o un texto del usuario.

const SqlDateConverter _dates = SqlDateConverter();

/// Fila recibida de Supabase, con lectores que validan el tipo de cada
/// columna y lanzan [FormatException] si no coincide.
extension type const RemoteJson(Map<String, dynamic> _json) {
  String string(String column) => _read<String>(column);

  String? nullableString(String column) => _readNullable<String>(column);

  /// bigint de PostgreSQL. Se rechazan los decimales: un monto nunca es
  /// double.
  int integer(String column) => _read<int>(column);

  int? nullableInteger(String column) => _readNullable<int>(column);

  /// timestamptz, en UTC.
  DateTime timestamp(String column) => _parseTimestamp(column, string(column));

  DateTime? nullableTimestamp(String column) {
    final value = nullableString(column);
    return value == null ? null : _parseTimestamp(column, value);
  }

  /// date ('AAAA-MM-DD'), igual que en la base local.
  DateTime date(String column) {
    final value = string(column);
    if (!_datePattern.hasMatch(value)) throw _invalid(column);
    return _dates.fromSql(value);
  }

  T _read<T>(String column) {
    final value = _json[column];
    if (value is! T) throw _invalid(column);
    return value;
  }

  T? _readNullable<T>(String column) {
    final value = _json[column];
    if (value == null) return null;
    if (value is! T) throw _invalid(column);
    return value;
  }

  static DateTime _parseTimestamp(String column, String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw _invalid(column);
    return parsed.toUtc();
  }

  static FormatException _invalid(String column) =>
      FormatException('Valor inválido en la columna $column');
}

final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// timestamptz para enviar: ISO-8601 en UTC, con microsegundos si los hay.
String timestampToRemote(DateTime value) => value.toUtc().toIso8601String();

/// date para enviar: 'AAAA-MM-DD'.
String dateToRemote(DateTime value) => _dates.toSql(value);
