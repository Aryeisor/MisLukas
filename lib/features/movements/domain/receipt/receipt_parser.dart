import '../../../../core/utils/clock.dart';
import '../entities/receipt_suggestion.dart';
import '../entities/recognized_receipt.dart';
import '../movement_text.dart';
import 'merchant_dictionary.dart';

/// Interpreta el texto de un recibo colombiano (docs/07 §7.3). Dart puro.
///
/// Extrae el total, el comercio, la fecha y una categoría sugerida. El texto
/// del recibo es un dato no confiable (docs/08 §8.6): solo se conservan esos
/// datos, limpios y con largo máximo, y el resto se descarta.
class ReceiptParser {
  const ReceiptParser();

  /// Mayor total que se acepta, en pesos. Un valor más alto es casi siempre
  /// una mala lectura (un NIT o un número de factura).
  static const int maxAmount = 100000000;

  /// Filas del inicio donde se busca el nombre del comercio.
  static const int merchantRows = 6;

  /// Filas del inicio donde se busca un comercio conocido.
  static const int knownMerchantRows = 8;

  /// Año mínimo de una fecha de compra; antes, es una mala lectura.
  static const int minYear = 2000;

  ReceiptSuggestion parse(
    RecognizedReceipt receipt, {
    required DateTime today,
  }) {
    final day = dateOnly(today);
    final rows = buildReceiptRows(receipt.lines);
    if (rows.isEmpty) return ReceiptSuggestion.empty(day);

    final total = _findTotal(rows);
    final known = _findKnownMerchant(rows);
    return ReceiptSuggestion(
      status: total != null
          ? ReceiptScanStatus.complete
          : ReceiptScanStatus.partial,
      total: total?.value,
      totalBox: total?.box,
      merchant: sanitizeDetectedText(known?.name ?? _findMerchantName(rows)),
      date: _findDate(rows, today: day),
      category:
          known?.category ??
          categoryFromKeywords(rows.map((row) => row.normalized).join(' ')),
    );
  }

  // ---------------------------------------------------------------- Total

  _Total? _findTotal(List<ReceiptRow> rows) {
    _Total? best;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      // Cada línea de ML Kit se evalúa por separado: el texto de otro bloque
      // a la misma altura (otro papel debajo del recibo) no descarta la fila
      // ni aporta su monto.
      for (var j = 0; j < row.lines.length; j++) {
        final line = row.lines[j];
        final priority = totalPriority(line.normalized);
        if (priority == null) continue;

        final found =
            _amountIn(line) ??
            _amountAfter(row.lines.skip(j + 1), line) ??
            (i + 1 < rows.length ? _amountBelow(rows[i + 1], line) : null);
        if (found == null) continue;

        // Gana la palabra clave más fuerte; con empate, la más abajo: el
        // total final va al pie, después de subtotales e impuestos.
        if (best == null || priority <= best.priority) {
          best = _Total(priority, found.value, found.box);
        }
      }
    }
    return best;
  }

  /// El último monto de la misma línea que la palabra clave.
  ({int value, ReceiptBox? box})? _amountIn(ReceiptLine line) {
    final value = _lastAmount(line.text);
    return value == null ? null : (value: value, box: line.box);
  }

  /// El monto que sigue a la palabra clave en la misma fila, si la primera
  /// línea con un monto a su derecha solo tiene ese monto.
  ({int value, ReceiptBox? box})? _amountAfter(
    Iterable<ReceiptLine> following,
    ReceiptLine keyword,
  ) {
    for (final line in following) {
      if (extractAmounts(line.text).isEmpty) continue;
      if (!isAmountOnly(line)) return null;
      return (
        value: _lastAmount(line.text)!,
        box: _union(keyword.box, line.box),
      );
    }
    return null;
  }

  /// El valor puede estar solo en la fila siguiente: la primera línea de esa
  /// fila que no queda a la izquierda de la palabra clave.
  ({int value, ReceiptBox? box})? _amountBelow(
    ReceiptRow next,
    ReceiptLine keyword,
  ) {
    final keywordBox = keyword.box;
    final candidates = [
      for (final line in next.lines)
        if (keywordBox == null ||
            line.box == null ||
            line.box!.right > keywordBox.left)
          line,
    ];
    if (candidates.isEmpty || !isAmountOnly(candidates.first)) return null;
    return (
      value: _lastAmount(candidates.first.text)!,
      box: _union(keywordBox, candidates.first.box),
    );
  }

  ReceiptBox? _union(ReceiptBox? a, ReceiptBox? b) =>
      a != null && b != null ? a.union(b) : null;

  int? _lastAmount(String text) {
    final amounts = extractAmounts(text);
    return amounts.isEmpty ? null : amounts.last;
  }

  // -------------------------------------------------------------- Comercio

  KnownMerchant? _findKnownMerchant(List<ReceiptRow> rows) {
    for (final row in rows.take(knownMerchantRows)) {
      final merchant = findKnownMerchant(row.normalized);
      if (merchant != null) return merchant;
    }
    return null;
  }

  String? _findMerchantName(List<ReceiptRow> rows) {
    for (final row in rows.take(merchantRows)) {
      if (isMerchantCandidate(row.normalized)) {
        return cleanMerchantName(row.text);
      }
    }
    return null;
  }

  // ----------------------------------------------------------------- Fecha

  DateTime _findDate(List<ReceiptRow> rows, {required DateTime today}) {
    DateTime? first;
    // Por línea de ML Kit, como el total: un "HASTA" de otro papel a la
    // misma altura no descarta la fecha del recibo.
    search:
    for (final row in rows) {
      for (final line in row.lines) {
        if (_dateExclusions.hasMatch(line.normalized)) continue;
        final dates = extractDates(line.normalized);
        if (dates.isEmpty) continue;
        if (_dateKeyword.hasMatch(line.normalized)) {
          first = dates.first;
          break search;
        }
        first ??= dates.first;
      }
    }
    // Una fecha futura o muy antigua es una mala lectura: se usa hoy.
    if (first == null || first.isAfter(today) || first.year < minYear) {
      return today;
    }
    return first;
  }
}

class _Total {
  const _Total(this.priority, this.value, this.box);

  final int priority;
  final int value;
  final ReceiptBox? box;
}

// ------------------------------------------------------------------ Filas

/// Una línea de ML Kit dentro de una fila.
class ReceiptLine {
  ReceiptLine(this.text, {this.box}) : normalized = normalizeReceiptText(text);

  final String text;
  final String normalized;
  final ReceiptBox? box;
}

/// Una fila visual del recibo: las líneas que están a la misma altura,
/// de izquierda a derecha.
class ReceiptRow {
  ReceiptRow(this.lines)
    : text = lines.map((line) => line.text).join(' '),
      normalized = lines.map((line) => line.normalized).join(' '),
      box = lines.any((line) => line.box == null)
          ? null
          : lines.map((line) => line.box!).reduce((a, b) => a.union(b));

  final List<ReceiptLine> lines;
  final String text;
  final String normalized;
  final ReceiptBox? box;
}

/// Agrupa las [lines] en filas visuales. ML Kit puede entregar "TOTAL" y
/// "$87.400" en bloques distintos: con su ubicación, quedan en la misma fila.
/// Si alguna línea no tiene ubicación, cada línea es una fila, en su orden.
List<ReceiptRow> buildReceiptRows(List<RecognizedLine> lines) {
  final useful = [
    for (final line in lines)
      if (line.text.trim().isNotEmpty) line,
  ];
  if (useful.any((line) => line.box == null)) {
    return [
      for (final line in useful) ReceiptRow([ReceiptLine(line.text.trim())]),
    ];
  }

  final sorted = [...useful]
    ..sort((a, b) => a.box!.centerY.compareTo(b.box!.centerY));
  final groups = <List<RecognizedLine>>[];
  for (final line in sorted) {
    if (groups.isNotEmpty && _sameRow(groups.last, line.box!)) {
      groups.last.add(line);
    } else {
      groups.add([line]);
    }
  }
  return [
    for (final group in groups)
      () {
        group.sort((a, b) => a.box!.left.compareTo(b.box!.left));
        return ReceiptRow([
          for (final line in group)
            ReceiptLine(line.text.trim(), box: line.box),
        ]);
      }(),
  ];
}

/// [box] está a la altura de [group]: sus centros están a menos de media
/// altura de la línea más baja.
bool _sameRow(List<RecognizedLine> group, ReceiptBox box) {
  final groupBox = group.map((line) => line.box!).reduce((a, b) => a.union(b));
  final smaller = box.height < groupBox.height ? box.height : groupBox.height;
  return (box.centerY - groupBox.centerY).abs() <= smaller / 2;
}

// ---------------------------------------------------------------- Textos

const Map<String, String> _accents = {
  'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A', //
  'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E', //
  'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I', //
  'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O', //
  'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U', //
  'Ñ': 'N',
};

final RegExp _spaces = RegExp(r'\s+');

/// Mayúsculas, sin tildes y con un solo espacio entre palabras.
String normalizeReceiptText(String text) {
  final upper = text.toUpperCase();
  final buffer = StringBuffer();
  for (final char in upper.split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString().replaceAll(_spaces, ' ').trim();
}

// ----------------------------------------------------------------- Montos

final RegExp _letterO = RegExp(r'(?<=[\d$][.,]?)O|O(?=[.,]?\d)');
final RegExp _time = RegExp(r'(?<!\d)\d{1,2}:\d{2}(?::\d{2})?(?!\d)');
final RegExp _card = RegExp(r'[*X]{2,}\s?\d+');

/// Un monto: con separadores de miles (punto, coma o espacio) y decimales
/// opcionales, o solo dígitos. No puede ser parte de otro número, de un NIT
/// (`890.900.608-9`), de un porcentaje ni de una tarjeta. Puede ir pegado a
/// una palabra ("TOTAL87.400"), como lo entrega a veces el OCR.
final RegExp _amount = RegExp(
  r'(?<![\d.,*/-])\$?\s?(\d{1,3}(?:[., ]\d{3})+(?:[.,]\d{2})?|\d+(?:[.,]\d{2})?)'
  r'(?![\d%]|[.,/-]?\d)',
);
final RegExp _decimals = RegExp(r'[.,]\d{2}$');
final RegExp _separators = RegExp(r'[., ]');

/// Montos de [text] en pesos, en el orden en que aparecen. Corrige la O
/// leída en lugar de un cero e ignora fechas, horas y tarjetas.
List<int> extractAmounts(String text) {
  var fixed = text.toUpperCase();
  String previous;
  do {
    previous = fixed;
    fixed = fixed.replaceAll(_letterO, '0');
  } while (fixed != previous);
  fixed = _removeDates(fixed).replaceAll(_time, ' ').replaceAll(_card, ' ');

  return [
    for (final match in _amount.allMatches(fixed))
      ?parseAmount(match.group(1)!),
  ];
}

/// "87.400", "87,400", "87 400", "87400", "87.400,00" o "87400.00" en pesos.
/// Null si está fuera de 1 a [ReceiptParser.maxAmount].
int? parseAmount(String raw) {
  var digits = raw.trim();
  // Dos dígitos después del último separador son centavos.
  if (_decimals.hasMatch(digits)) {
    digits = digits.substring(0, digits.length - 3);
  }
  final value = int.tryParse(digits.replaceAll(_separators, ''));
  if (value == null || value < 1 || value > ReceiptParser.maxAmount) {
    return null;
  }
  return value;
}

/// La línea solo tiene un monto (el valor de la palabra clave).
bool isAmountOnly(ReceiptLine line) {
  if (extractAmounts(line.text).isEmpty) return false;
  return !RegExp(r'[A-Z]{2,}').hasMatch(line.normalized);
}

// ------------------------------------------------------------------ Total

/// Palabras clave del total, de la más fuerte a la más débil. "VALOR" y
/// "SALDO" solos no son palabras clave: acompañan a casi cualquier fila de
/// una factura de servicios.
final List<RegExp> _totalKeywords = [
  // Lo que se paga o ya se pagó.
  RegExp(
    r'\b(?:TOTAL A PAGAR|VALOR A PAGAR|TOTAL PAGAR|NETO A PAGAR|GRAN TOTAL|'
    r'TOTAL CON PROPINA|TOTAL GENERAL|VALOR PAGADO|TOTAL PAGADO|SALDO PAGADO|'
    r'MONTO PAGADO|VALOR DEL PAGO|VALOR PAGO|PAGO TOTAL|TOTAL A CANCELAR|'
    r'VALOR A CANCELAR|PAGUE ESTE VALOR|TOTAL PAGO OPORTUNO|PAGO OPORTUNO)\b',
  ),
  RegExp(
    r'\b(?:VALOR TOTAL|TOTAL FACTURA|TOTAL FACTURADO|VALOR FACTURA|'
    r'TOTAL VENTA|TOTAL COMPRA|IMPORTE TOTAL|MONTO TOTAL|IMPORTE|MONTO)\b',
  ),
  RegExp(r'\b(?:TOTAL|NETO)\b'),
];

/// Nunca es el total final.
final RegExp _subtotal = RegExp(r'\bSUB ?-?TOTAL(?:ES)?\b');

/// Valores que acompañan a "TOTAL" pero no son lo que se pagó: impuestos,
/// propina, descuentos, pago en efectivo, cambio y conteos de productos. No
/// aplica a las palabras clave más fuertes ("TOTAL CON PROPINA").
final RegExp _totalExclusions = RegExp(
  r'\b(?:IVA|IMPUESTOS?|INC|IMPOCONSUMO|BASE|PROPINAS?|SERVICIO|DESCUENTOS?|'
  r'DCTOS?|AHORRO|EFECTIVO|RECIBIDO|CAMBIO|VUELTOS?|ITEMS?|ARTICULOS|'
  r'UNIDADES|PUNTOS|PESO|REDONDEO|DONACION)\b',
);

/// Valores de una factura de servicios o de un crédito que nunca son lo que
/// se pagó: tarifas, consumo, subsidios, contribuciones, mora, recargos,
/// saldos y cuotas. Aplica también a las palabras clave más fuertes
/// ("VALOR A PAGAR CON RECARGO").
final RegExp _billExclusions = RegExp(
  r'\b(?:VALOR (?:DEL? )?(?:UNITARIO|KWH|CONSUMO|IVA)|SUBSIDIOS?|'
  r'CONTRIBUCION(?:ES)?|MORA|RECARGOS?|SALDO (?:ANTERIOR|PENDIENTE|A FAVOR)|'
  r'PAGO MINIMO|CUOTAS?|ABONOS?)\b',
);

/// Un cero pegado a una letra es una O mal leída ("VAL0R PAGAD0").
final RegExp _zeroAsLetter = RegExp(r'(?<=[A-Z])0|0(?=[A-Z])');

/// Prioridad de la fila como total (0 es la más fuerte), o null si no lo es.
int? totalPriority(String normalized) {
  final text = normalized.replaceAll(_zeroAsLetter, 'O');
  if (_subtotal.hasMatch(text)) return null;
  if (_billExclusions.hasMatch(text)) return null;
  for (var i = 0; i < _totalKeywords.length; i++) {
    if (!_totalKeywords[i].hasMatch(text)) continue;
    if (i > 0 && _totalExclusions.hasMatch(text)) return null;
    return i;
  }
  return null;
}

// --------------------------------------------------------------- Comercio

final RegExp _merchantExclusions = RegExp(
  r'\b(?:NIT|N\.?I\.?T|RUT|TEL|TELEFONO|CEL|CELULAR|PBX|FACTURA|RESOLUCION|'
  r'DIAN|REGIMEN|RESPONSABLE|AUTORRETENEDOR|TIQUETE|TICKET|POS|CAJA|CAJERO|'
  r'BIENVENIDOS?|GRACIAS|FECHA|HORA|SUCURSAL|DIRECCION|WWW|HTTPS?|COPIA|'
  r'ORIGINAL|DOCUMENTO|ELECTRONICA)\b|#|@',
);
final RegExp _address = RegExp(
  r'^(?:CL|CLL|CALLE|CR|CRA|KR|KRA|CARRERA|AV|AVENIDA|AK|AC|DG|DIAGONAL|TV|'
  r'TRANSVERSAL)\b',
);
final RegExp _letters = RegExp(r'[A-Z]');
final RegExp _digits = RegExp(r'\d');

/// La fila puede ser el nombre del comercio: tiene al menos 3 letras, más
/// letras que dígitos y no es un NIT, una dirección, un teléfono ni un
/// encabezado de factura.
bool isMerchantCandidate(String normalized) {
  if (_merchantExclusions.hasMatch(normalized)) return false;
  if (_address.hasMatch(normalized)) return false;
  if (extractDates(normalized).isNotEmpty) return false;
  final letters = _letters.allMatches(normalized).length;
  final digits = _digits.allMatches(normalized).length;
  return letters >= 3 && letters > digits;
}

final RegExp _legalSuffix = RegExp(
  r'[\s,.]*\b(?:S\.?\s?A\.?\s?S\.?|S\.?\s?A\.?|LTDA\.?|E\.?\s?U\.?|S\.?\s?C\.?\s?A\.?)\s*$',
  caseSensitive: false,
);
final RegExp _edgePunctuation = RegExp(
  r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$',
  unicode: true,
);
const Set<String> _connectors = {'de', 'del', 'la', 'las', 'los', 'el', 'y'};

/// Nombre del comercio para mostrar: sin la razón social (S.A.S., LTDA) y,
/// si viene todo en mayúsculas, con mayúscula inicial ("Restaurante La
/// Cazuela").
String cleanMerchantName(String text) {
  var name = text.replaceAll(_spaces, ' ').trim();
  name = name.replaceFirst(_legalSuffix, '');
  name = name.replaceAll(_edgePunctuation, '');
  if (name != name.toUpperCase()) return name;

  final words = name.toLowerCase().split(' ');
  return [
    for (var i = 0; i < words.length; i++)
      i > 0 && _connectors.contains(words[i])
          ? words[i]
          : _capitalize(words[i]),
  ].join(' ');
}

String _capitalize(String word) =>
    word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);

// ----------------------------------------------------------------- Fechas

final RegExp _dateKeyword = RegExp(r'\bFECHA\b');

/// Fechas que no son la de la compra: resolución de facturación, vigencias,
/// vencimientos y periodos de un servicio.
final RegExp _dateExclusions = RegExp(
  r'\b(?:RESOLUCION|DIAN|AUTORIZA\w*|VIGEN\w*|VENCE|VENCIMIENTO|VCTO|LIMITE|'
  r'HASTA|DESDE|OPORTUNO|SUSPENSION|CORTE|PERIODO|RANGO|PREFIJO)\b',
);

final RegExp _yearFirst = RegExp(
  r'(?<!\d)(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})(?!\d)',
);
final RegExp _dayFirst = RegExp(
  r'(?<!\d)(\d{1,2})\s?[/\-.]\s?(\d{1,2})\s?[/\-.]\s?(\d{4}|\d{2})(?!\d)',
);
final RegExp _monthName = RegExp(
  r'(?<!\d)(\d{1,2})[\s\-/.]*(?:DE\s+)?'
  r'(ENE|FEB|MAR|ABR|MAY|JUN|JUL|AGO|SEP|SET|OCT|NOV|DIC)[A-Z]*\.?'
  r'[\s\-/.]*(?:DE\s+)?(\d{4}|\d{2})(?!\d)',
);

const Map<String, int> _months = {
  'ENE': 1, 'FEB': 2, 'MAR': 3, 'ABR': 4, 'MAY': 5, 'JUN': 6, //
  'JUL': 7, 'AGO': 8, 'SEP': 9, 'SET': 9, 'OCT': 10, 'NOV': 11, 'DIC': 12,
};

/// Fechas válidas de [normalized], en orden: aaaa-mm-dd, dd/mm/aaaa,
/// dd-mm-aa, dd.mm.aaaa y "17 OCT 2026". El día va antes que el mes.
List<DateTime> extractDates(String normalized) {
  final found = <(int, DateTime)>[];
  for (final match in _yearFirst.allMatches(normalized)) {
    final date = _validDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
    if (date != null) found.add((match.start, date));
  }
  final rest = normalized.replaceAll(_yearFirst, ' ');
  for (final match in _dayFirst.allMatches(rest)) {
    final date = _validDate(
      _fullYear(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
    );
    if (date != null) found.add((match.start, date));
  }
  for (final match in _monthName.allMatches(rest)) {
    final date = _validDate(
      _fullYear(match.group(3)!),
      _months[match.group(2)!]!,
      int.parse(match.group(1)!),
    );
    if (date != null) found.add((match.start, date));
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, date) in found) date];
}

/// Quita de [text] (en mayúsculas) todo lo que parece una fecha: nunca es un
/// monto.
String _removeDates(String text) => text
    .replaceAll(_yearFirst, ' ')
    .replaceAll(_dayFirst, ' ')
    .replaceAll(_monthName, ' ');

int _fullYear(String year) =>
    year.length == 2 ? 2000 + int.parse(year) : int.parse(year);

/// La fecha si existe en el calendario (sin 31 de febrero), o null.
DateTime? _validDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}
