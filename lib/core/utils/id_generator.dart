import 'package:uuid/uuid.dart';

/// Genera los identificadores de los registros en el dispositivo (docs/06
/// §6.4.1). Los casos de uso dependen de esta interfaz para poder fijar los
/// identificadores en las pruebas.
abstract interface class IdGenerator {
  String newId();
}

/// Identificadores UUID v4 (aleatorios).
class UuidIdGenerator implements IdGenerator {
  const UuidIdGenerator();

  static const Uuid _uuid = Uuid();

  @override
  String newId() => _uuid.v4();
}
