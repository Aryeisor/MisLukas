import '../../../movements/domain/entities/movement.dart';
import 'category.dart';

/// Categorías predeterminadas con UUID fijos.
///
/// Los identificadores son constantes para que sean iguales en todos los
/// dispositivos y en el servidor (Fase 5). No se deben cambiar nunca.
enum DefaultCategory {
  mercado(
    id: '2909b516-0ab3-493e-b8e8-90f8ccf28aed',
    displayName: 'Mercado',
    type: MovementType.expense,
  ),
  transporte(
    id: '3a406a70-09bd-4b1e-b945-1b2600f5bb12',
    displayName: 'Transporte',
    type: MovementType.expense,
  ),
  ocio(
    id: '69f498cd-1f9f-4c86-bcb5-166d76cec417',
    displayName: 'Ocio',
    type: MovementType.expense,
  ),
  servicios(
    id: 'cabdf6bb-527d-477d-a489-bad388d5c482',
    displayName: 'Servicios',
    type: MovementType.expense,
  ),
  restaurantes(
    id: '36b145c6-2ea6-4067-b264-5d69270f0367',
    displayName: 'Restaurantes',
    type: MovementType.expense,
  ),
  otros(
    id: '14ba8c36-dfee-4253-ab2e-13ac6ef7ebd0',
    displayName: 'Otros',
    type: MovementType.expense,
  ),
  ingreso(
    id: '7d4c2cae-fe7f-4353-80ac-2947009b026d',
    displayName: 'Ingreso',
    type: MovementType.income,
  );

  const DefaultCategory({
    required this.id,
    required this.displayName,
    required this.type,
  });

  final String id;

  /// Nombre visible.
  final String displayName;
  final MovementType type;

  /// Clave estable ("mercado"), igual al nombre del valor del enum.
  String get key => name;

  Category toCategory() => Category(
    id: id,
    key: key,
    name: displayName,
    type: type,
    isDefault: true,
  );

  static final Map<String, DefaultCategory> _byId = {
    for (final category in values) category.id: category,
  };

  /// Categoría predeterminada con [id], o null si es personalizada.
  static DefaultCategory? fromId(String id) => _byId[id];
}
