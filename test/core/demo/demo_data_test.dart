import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/demo/demo_data.dart';
import 'package:mislukas/core/theme/category_style.dart';

void main() {
  test('arranca con los 5 movimientos de septiembre', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final movements = container.read(demoMovementsProvider);
    expect(movements.map((m) => m.title), [
      'Éxito',
      'TransMilenio',
      'Salario',
      'Juan Valdez',
      'Freelance',
    ]);
  });

  test('addExpense agrega el gasto al inicio con fecha de hoy', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(demoMovementsProvider.notifier)
        .addExpense(title: 'Taxi', category: CategoryKind.transporte, amount: 25000);

    final movements = container.read(demoMovementsProvider);
    expect(movements, hasLength(6));
    expect(movements.first.title, 'Taxi');
    expect(movements.first.amount, 25000);
    expect(movements.first.isIncome, isFalse);
    expect(movements.first.date, demoReferenceDate);
    // Los ids no se repiten.
    expect(movements.map((m) => m.id).toSet(), hasLength(6));
  });
}
