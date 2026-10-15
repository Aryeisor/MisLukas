import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/features/simulator/presentation/simulator_providers.dart';
import 'package:mislukas/features/simulator/presentation/simulator_state.dart';
import 'package:mislukas/features/simulator/presentation/simulator_view_model.dart';

import '../../../helpers/domain_fixtures.dart';
import '../../../helpers/test_container.dart';

void main() {
  ProviderContainer createContainer({int? average = 420000}) {
    final container = ProviderContainer(
      overrides: [
        savingsAverageProvider.overrideWithValue(
          AsyncData(savingsAverageOf(average)),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Mantiene vivo el ViewModel entre lecturas.
    container.listen(simulatorViewModelProvider, (_, _) {});
    return container;
  }

  SimulatorData read(ProviderContainer container) =>
      container.read(simulatorViewModelProvider) as SimulatorData;

  test('periodo: los meses que realmente se usaron', () {
    expect(
      savingsPeriodLabel(DateTime(2026, 6), DateTime(2026, 8)),
      'Junio – Agosto 2026',
    );
    expect(
      savingsPeriodLabel(DateTime(2025, 11), DateTime(2026, 1)),
      'Noviembre 2025 – Enero 2026',
    );
    expect(
      savingsPeriodLabel(DateTime(2026, 8), DateTime(2026, 8)),
      'Agosto 2026',
    );
  });

  test('con la base sembrada: 420.000 de junio a agosto', () async {
    final (container, _) = await createTestContainer();
    final state = await waitForState(
      container,
      simulatorViewModelProvider,
      (s) => s is! SimulatorLoading,
    );
    final data = state as SimulatorData;
    expect(data.averageSavings, 420000);
    expect(data.periodLabel, 'Junio – Agosto 2026');
  });

  test('con la base vacía: sin datos suficientes', () async {
    final (container, _) = await createTestContainer(seed: false);
    final state = await waitForState(
      container,
      simulatorViewModelProvider,
      (s) => s is! SimulatorLoading,
    );
    expect(state, isA<SimulatorNoData>());
  });

  test('estado inicial: 3 años y aporte igual al promedio', () {
    final data = read(createContainer());
    expect(data.periodLabel, 'Junio – Agosto 2026');
    expect(data.averageSavings, 420000);
    expect(data.years, 3);
    expect(data.monthlyContribution, 420000);
    expect(data.projection.withoutInterest, 15120000);
    expect(data.projection.withInterest, 16716595);
    expect(data.projection.interest, 1596595);
    expect(data.yearlySeries, hasLength(3));
    expect(data.boostedProjection.withInterest, 18706666);
    expect(data.boostDifference, 1990071);
  });

  test('setYears recalcula y se limita de 1 a 10', () {
    final container = createContainer();
    final viewModel = container.read(simulatorViewModelProvider.notifier);

    viewModel.setYears(1);
    expect(read(container).projection.withInterest, 5199725);
    expect(read(container).yearlySeries, hasLength(1));

    viewModel.setYears(15);
    expect(read(container).years, 10);
    viewModel.setYears(0);
    expect(read(container).years, 1);
  });

  test('aporte en pasos de 50.000 con mínimo de 50.000', () {
    final container = createContainer(average: 100000);
    final viewModel = container.read(simulatorViewModelProvider.notifier);

    viewModel.increaseContribution();
    expect(read(container).monthlyContribution, 150000);
    expect(read(container).projection.withoutInterest, 150000 * 36);

    viewModel.decreaseContribution();
    viewModel.decreaseContribution();
    expect(read(container).monthlyContribution, 50000);
    expect(read(container).canDecrease, isFalse);

    viewModel.decreaseContribution();
    expect(read(container).monthlyContribution, 50000);
  });

  test('promedio menor al mínimo arranca en el mínimo', () {
    expect(read(createContainer(average: 20000)).monthlyContribution, 50000);
  });

  test('ahorro cero o negativo: sin proyección', () {
    expect(
      createContainer(average: 0).read(simulatorViewModelProvider),
      isA<SimulatorNotSaving>(),
    );
    expect(
      createContainer(average: -150000).read(simulatorViewModelProvider),
      isA<SimulatorNotSaving>(),
    );
  });

  test('sin datos suficientes', () {
    expect(
      createContainer(average: null).read(simulatorViewModelProvider),
      isA<SimulatorNoData>(),
    );
  });
}
