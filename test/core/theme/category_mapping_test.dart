import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/theme/category_mapping.dart';
import 'package:mislukas/core/theme/category_style.dart';
import 'package:mislukas/features/budgets/domain/entities/default_categories.dart';

void main() {
  test('cada CategoryKind corresponde a una categoría predeterminada', () {
    for (final kind in CategoryKind.values) {
      expect(kind.defaultCategory.kind, kind);
      expect(kind.defaultCategory.displayName, kind.label);
      expect(categoryKindForId(kind.categoryId), kind);
    }
    expect(
      DefaultCategory.values.map((c) => c.kind).toSet(),
      CategoryKind.values.toSet(),
    );
  });

  test('una categoría desconocida usa el estilo de Otros', () {
    expect(categoryKindForId('personalizada'), CategoryKind.otros);
  });
}
