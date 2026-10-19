import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/features/budgets/data/device_notification_services.dart';
import 'package:mislukas/features/budgets/domain/entities/budget_alert.dart';
import 'package:mislukas/features/budgets/domain/entities/budget_alert_notice.dart';

BudgetAlert _alert(String categoryId, int percent) => BudgetAlert(
  categoryId: categoryId,
  month: DateTime(2026, 10),
  limitAmount: 100000,
  spent: percent * 1000,
  percent: percent,
  threshold: percent >= 100
      ? BudgetAlertThreshold.exceeded
      : BudgetAlertThreshold.warning,
);

BudgetAlertNotice _notice(int percent) => BudgetAlertNotice(
  categoryId: 'mercado',
  categoryName: 'Mercado',
  month: DateTime(2026, 10),
  percent: percent,
  threshold: percent >= 100
      ? BudgetAlertThreshold.exceeded
      : BudgetAlertThreshold.warning,
);

void main() {
  group('pendingBudgetAlerts', () {
    test('al 75% registra y notifica el 75%', () {
      final pending = pendingBudgetAlerts(
        alerts: [_alert('mercado', 78)],
        sent: const {},
      );
      expect(pending.toRecord, [('mercado', BudgetAlertThreshold.warning)]);
      expect(pending.toNotify.single.percent, 78);
    });

    test('cruzar el 75% y el 100% a la vez registra los dos y notifica '
        'solo el 100%', () {
      final pending = pendingBudgetAlerts(
        alerts: [_alert('mercado', 120)],
        sent: const {},
      );
      expect(pending.toRecord, [
        ('mercado', BudgetAlertThreshold.warning),
        ('mercado', BudgetAlertThreshold.exceeded),
      ]);
      expect(
        pending.toNotify.single.threshold,
        BudgetAlertThreshold.exceeded,
      );
    });

    test('un umbral ya registrado no se repite', () {
      final pending = pendingBudgetAlerts(
        alerts: [_alert('mercado', 90)],
        sent: const {('mercado', BudgetAlertThreshold.warning)},
      );
      expect(pending.toRecord, isEmpty);
      expect(pending.toNotify, isEmpty);
    });

    test('con el 100% registrado y el gasto de vuelta en 80% no notifica', () {
      final pending = pendingBudgetAlerts(
        alerts: [_alert('mercado', 80)],
        sent: const {
          ('mercado', BudgetAlertThreshold.warning),
          ('mercado', BudgetAlertThreshold.exceeded),
        },
      );
      expect(pending.toRecord, isEmpty);
      expect(pending.toNotify, isEmpty);
    });

    test('con el 100% registrado sin el 75% registra el 75% sin '
        'notificarlo', () {
      final pending = pendingBudgetAlerts(
        alerts: [_alert('mercado', 110)],
        sent: const {('mercado', BudgetAlertThreshold.exceeded)},
      );
      expect(pending.toRecord, [('mercado', BudgetAlertThreshold.warning)]);
      expect(pending.toNotify, isEmpty);
    });
  });

  group('texto de la notificación', () {
    test('75%: porcentaje real y categoría', () {
      expect(_notice(78).body, 'Llevas el 78% de tu presupuesto de Mercado.');
    });

    test('exactamente 100%: "Llegaste al 100%" con el mes', () {
      expect(
        _notice(100).body,
        'Llegaste al 100% de tu presupuesto de Mercado de octubre.',
      );
    });

    test('más de 100%: "Superaste" con el mes', () {
      expect(
        _notice(134).body,
        'Superaste tu presupuesto de Mercado de octubre.',
      );
    });

    test('nunca lleva montos', () {
      expect(BudgetAlertNotice.title, 'Alerta de presupuesto');
      for (final percent in [75, 99, 100, 101, 250]) {
        final body = _notice(percent).body;
        expect(body, isNot(contains(r'$')));
        // Solo el porcentaje: ningún número con separador de miles.
        expect(body, isNot(matches(RegExp(r'\d{1,3}(\.\d{3})+'))));
        expect(
          RegExp(r'\d+').allMatches(body).map((m) => m.group(0)),
          everyElement(anyOf('$percent', '100')),
        );
      }
    });
  });

  test('el id de la notificación es estable por categoría y mes', () {
    final october = budgetAlertNotificationId('mercado', DateTime(2026, 10));
    expect(budgetAlertNotificationId('mercado', DateTime(2026, 10)), october);
    expect(
      budgetAlertNotificationId('mercado', DateTime(2026, 11)),
      isNot(october),
    );
    expect(
      budgetAlertNotificationId('ocio', DateTime(2026, 10)),
      isNot(october),
    );
    expect(october, inInclusiveRange(0, 0x7fffffff));
  });
}
