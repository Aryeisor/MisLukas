// Comercios frecuentes en Colombia y palabras de los recibos que sugieren una
// categoría (docs/07 §7.3, RF-16). Dart puro.
//
// Los patrones se comparan con el texto normalizado: mayúsculas, sin tildes y
// con un solo espacio entre palabras (normalizeReceiptText).

import '../../../budgets/domain/entities/default_categories.dart';

/// Un comercio conocido: cómo aparece en el recibo, su nombre y su categoría.
class KnownMerchant {
  KnownMerchant(String pattern, this.name, this.category)
    : pattern = RegExp('\\b(?:$pattern)\\b');

  final RegExp pattern;
  final String name;
  final DefaultCategory category;
}

final List<KnownMerchant> knownMerchants = [
  // Mercado
  KnownMerchant(r'EXITO', 'Éxito', DefaultCategory.mercado),
  KnownMerchant(r'CARULLA', 'Carulla', DefaultCategory.mercado),
  KnownMerchant(r'TIENDAS? D1|D1', 'D1', DefaultCategory.mercado),
  KnownMerchant(r'TIENDAS ARA|ARA', 'Ara', DefaultCategory.mercado),
  KnownMerchant(r'OLIMPICA', 'Olímpica', DefaultCategory.mercado),
  KnownMerchant(r'JUMBO', 'Jumbo', DefaultCategory.mercado),
  KnownMerchant(r'MAKRO', 'Makro', DefaultCategory.mercado),
  KnownMerchant(r'PRICESMART', 'PriceSmart', DefaultCategory.mercado),
  KnownMerchant(r'SURTIMAX', 'Surtimax', DefaultCategory.mercado),
  KnownMerchant(r'SUPER INTER', 'Super Inter', DefaultCategory.mercado),
  KnownMerchant(r'ISIMO', 'Ísimo', DefaultCategory.mercado),
  // Transporte
  KnownMerchant(r'TERPEL', 'Terpel', DefaultCategory.transporte),
  KnownMerchant(r'PRIMAX', 'Primax', DefaultCategory.transporte),
  KnownMerchant(r'BIOMAX', 'Biomax', DefaultCategory.transporte),
  KnownMerchant(r'ESSO', 'Esso', DefaultCategory.transporte),
  KnownMerchant(r'MOBIL', 'Mobil', DefaultCategory.transporte),
  KnownMerchant(r'TEXACO', 'Texaco', DefaultCategory.transporte),
  KnownMerchant(r'TRANSMILENIO', 'TransMilenio', DefaultCategory.transporte),
  KnownMerchant(
    r'METRO DE MEDELLIN',
    'Metro de Medellín',
    DefaultCategory.transporte,
  ),
  KnownMerchant(r'CABIFY', 'Cabify', DefaultCategory.transporte),
  // Ocio
  KnownMerchant(r'JUAN VALDEZ', 'Juan Valdez', DefaultCategory.ocio),
  KnownMerchant(r'TOSTAO', 'Tostao', DefaultCategory.ocio),
  KnownMerchant(r'STARBUCKS', 'Starbucks', DefaultCategory.ocio),
  KnownMerchant(r'CINE COLOMBIA', 'Cine Colombia', DefaultCategory.ocio),
  KnownMerchant(r'CINEMARK', 'Cinemark', DefaultCategory.ocio),
  KnownMerchant(r'PROCINAL', 'Procinal', DefaultCategory.ocio),
  KnownMerchant(r'CINEPOLIS', 'Cinépolis', DefaultCategory.ocio),
  // Restaurantes
  KnownMerchant(r'EL CORRAL', 'El Corral', DefaultCategory.restaurantes),
  KnownMerchant(r'FRISBY', 'Frisby', DefaultCategory.restaurantes),
  KnownMerchant(
    r'CREPES (?:&|AND|Y) WAFFLES',
    'Crepes & Waffles',
    DefaultCategory.restaurantes,
  ),
  KnownMerchant(r'MC ?DONALD.?S?', "McDonald's", DefaultCategory.restaurantes),
  KnownMerchant(r'KFC', 'KFC', DefaultCategory.restaurantes),
  KnownMerchant(r'PRESTO', 'Presto', DefaultCategory.restaurantes),
  KnownMerchant(r'SUBWAY', 'Subway', DefaultCategory.restaurantes),
  KnownMerchant(r'KOKORIKO', 'Kokoriko', DefaultCategory.restaurantes),
  KnownMerchant(r'BURGER KING', 'Burger King', DefaultCategory.restaurantes),
  KnownMerchant(r'DOMINO.?S', "Domino's", DefaultCategory.restaurantes),
  KnownMerchant(
    r'SANDWICH QBANO',
    'Sandwich Qbano',
    DefaultCategory.restaurantes,
  ),
  // Servicios
  KnownMerchant(
    r'EPM|EMPRESAS PUBLICAS DE MEDELLIN',
    'EPM',
    DefaultCategory.servicios,
  ),
  KnownMerchant(r'ENEL|CODENSA', 'Enel', DefaultCategory.servicios),
  KnownMerchant(r'VANTI', 'Vanti', DefaultCategory.servicios),
  KnownMerchant(r'EMCALI', 'Emcali', DefaultCategory.servicios),
  KnownMerchant(r'CELSIA', 'Celsia', DefaultCategory.servicios),
  KnownMerchant(r'AFINIA', 'Afinia', DefaultCategory.servicios),
  KnownMerchant(r'AIR ?- ?E', 'Air-e', DefaultCategory.servicios),
  KnownMerchant(r'ESSA', 'Essa', DefaultCategory.servicios),
  KnownMerchant(r'CENS', 'Cens', DefaultCategory.servicios),
  KnownMerchant(r'ELECTRICARIBE', 'Electricaribe', DefaultCategory.servicios),
  KnownMerchant(
    r'GASES DEL CARIBE',
    'Gases del Caribe',
    DefaultCategory.servicios,
  ),
  KnownMerchant(r'ETB', 'ETB', DefaultCategory.servicios),
  KnownMerchant(r'CLARO', 'Claro', DefaultCategory.servicios),
  KnownMerchant(r'MOVISTAR', 'Movistar', DefaultCategory.servicios),
  KnownMerchant(r'TIGO', 'Tigo', DefaultCategory.servicios),
  // Otros (droguerías)
  KnownMerchant(r'CRUZ VERDE', 'Cruz Verde', DefaultCategory.otros),
  KnownMerchant(r'FARMATODO', 'Farmatodo', DefaultCategory.otros),
  KnownMerchant(
    r'(?:DROGUERIAS? )?LA REBAJA',
    'La Rebaja',
    DefaultCategory.otros,
  ),
  KnownMerchant(r'LOCATEL', 'Locatel', DefaultCategory.otros),
  KnownMerchant(r'PASTEUR', 'Pasteur', DefaultCategory.otros),
];

/// Palabras del recibo que sugieren una categoría si el comercio no está en
/// [knownMerchants]. Se revisan en este orden: la primera que coincide gana.
final List<(RegExp, DefaultCategory)> categoryKeywords = [
  (
    RegExp(
      r'\b(?:GASOLINA|ACPM|DIESEL|COMBUSTIBLE|GALON(?:ES)?|ESTACION DE SERVICIO|EDS|PEAJE|PARQUEADERO)\b',
    ),
    DefaultCategory.transporte,
  ),
  (
    RegExp(
      r'\b(?:ENERGIA|ACUEDUCTO|ALCANTARILLADO|GAS NATURAL|INTERNET|TELEFONIA|SERVICIOS PUBLICOS)\b',
    ),
    DefaultCategory.servicios,
  ),
  (RegExp(r'\b(?:DROGUERIA|FARMACIA|DROGAS)\b'), DefaultCategory.otros),
  (
    RegExp(
      r'\b(?:SUPERMERCADO|MINIMERCADO|AUTOSERVICIO|SUPERTIENDA|FRUVER|MERCADO)\b',
    ),
    DefaultCategory.mercado,
  ),
  (
    RegExp(
      r'\b(?:RESTAURANTE|ASADERO|PIZZERIA|COMIDAS RAPIDAS|PANADERIA|PROPINA)\b',
    ),
    DefaultCategory.restaurantes,
  ),
  (
    RegExp(r'\b(?:CINE|TEATRO|DISCOTECA|BAR|CAFE|CAFETERIA)\b'),
    DefaultCategory.ocio,
  ),
];

/// Primer comercio conocido que aparece en [normalizedText], o null.
KnownMerchant? findKnownMerchant(String normalizedText) {
  for (final merchant in knownMerchants) {
    if (merchant.pattern.hasMatch(normalizedText)) return merchant;
  }
  return null;
}

/// Categoría sugerida por las palabras de [normalizedText], o null.
DefaultCategory? categoryFromKeywords(String normalizedText) {
  for (final (pattern, category) in categoryKeywords) {
    if (pattern.hasMatch(normalizedText)) return category;
  }
  return null;
}
