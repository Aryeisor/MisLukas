import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/database/seed/demo_seed.dart';
import 'package:mislukas/core/theme/app_theme.dart';
import 'package:mislukas/core/utils/clock.dart';
import 'package:mislukas/core/utils/date_formatter.dart';
import 'package:mislukas/core/utils/utils_providers.dart';
import 'package:mislukas/core/widgets/dev/demo_data_actions.dart';
import 'package:mislukas/core/widgets/widgets.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/pump_screen.dart';
import '../../../helpers/test_session.dart';

void main() {
  String dayLabel(DateTime day) =>
      '${day.day} de ${DateLabels.monthName(day)} de ${day.year}';

  Future<ProviderContainer> pumpActions(
    WidgetTester tester, {
    bool demoTools = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoToolsEnabledProvider.overrideWithValue(demoTools),
          authOverride(FakeAuthRepository()),
          ...TestSession().overrides(null),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(child: DemoDataActions()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(DemoDataActions)),
    );
  }

  testWidgets('adelantar un mes cambia el "hoy" de la app y se puede volver', (
    tester,
  ) async {
    final container = await pumpActions(tester);
    final real = container.read(clockProvider).today();
    expect(find.text('Fecha real: ${dayLabel(real)}'), findsOneWidget);
    final back = find.widgetWithText(
      AppSecondaryButton,
      'Volver a la fecha real',
    );
    expect(tester.widget<AppSecondaryButton>(back).onPressed, isNull);

    await tester.tap(find.text('Adelantar un mes'));
    await tester.pumpAndSettle();

    final simulated = shiftMonths(real, 1);
    expect(container.read(clockProvider).today(), simulated);
    expect(find.text('Fecha simulada: ${dayLabel(simulated)}'), findsOneWidget);
    expect(tester.widget<AppSecondaryButton>(back).onPressed, isNotNull);

    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(container.read(debugMonthOffsetProvider), 0);
    expect(find.text('Fecha real: ${dayLabel(real)}'), findsOneWidget);
  });

  testWidgets('fuera de modo desarrollo no se muestra', (tester) async {
    await pumpActions(tester, demoTools: false);
    expect(find.text('Adelantar un mes'), findsNothing);
  });
}
