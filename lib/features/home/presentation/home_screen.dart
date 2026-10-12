import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import 'home_state.dart';
import 'home_view_model.dart';

/// Pantalla de Inicio (pantalla 5, fig. 5.4).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeViewModelProvider);
    void openNewMovement() => context.push(AppRoutes.newMovement);

    final content = switch (state) {
      HomeLoading() => const Center(child: CircularProgressIndicator()),
      HomeError(:final message) => ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          AppBanner(
            variant: AppBannerVariant.error,
            title: 'No pudimos cargar tu información',
            description: message,
          ),
        ],
      ),
      HomeEmpty(:final monthLabel, :final userName) => ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          _Header(monthLabel: monthLabel, userName: userName),
          const SizedBox(height: AppSpacing.xl),
          AppEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Aún no tienes movimientos este mes',
            description: 'Registra tu primer gasto para ver en qué se va tu dinero.',
            actionLabel: 'Registrar mi primer gasto',
            onAction: openNewMovement,
          ),
        ],
      ),
      HomeData() => _HomeDataView(data: state),
    };

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(child: content),
            // Botón fijo sobre la barra inferior; la lista termina antes de él.
            if (state is HomeData)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.sm,
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                ),
                child: AppPrimaryButton(
                  label: 'Nuevo gasto',
                  icon: Icons.add,
                  onPressed: openNewMovement,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeDataView extends StatelessWidget {
  const _HomeDataView({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final alert = data.budgetAlert;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.screenPadding,
        AppSpacing.screenPadding,
        AppSpacing.xl,
      ),
      children: [
        _Header(monthLabel: data.monthLabel, userName: data.userName),
        const SizedBox(height: AppSpacing.xl),
        AppSummaryCard(
          label: 'Disponible este mes',
          value: CurrencyFormatter.format(data.available),
          items: [
            AppSummaryItem(
              icon: Icons.arrow_upward,
              label: 'Ingresos',
              value: CurrencyFormatter.format(data.income),
            ),
            AppSummaryItem(
              icon: Icons.arrow_downward,
              label: 'Gastos',
              value: CurrencyFormatter.format(data.expenses),
            ),
          ],
        ),
        if (alert != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _BudgetAlertBanner(alert: alert),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppSectionHeader(
          title: 'Últimos movimientos',
          actionLabel: 'Ver todos',
          onAction: () => AppSnackbar.info(context, 'Disponible próximamente'),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final movement in data.latestMovements) ...[
          MovementTile(
            key: ValueKey(movement.id),
            title: movement.title,
            category: movement.category,
            dateLabel: movement.dateLabel,
            amount: movement.amount,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.monthLabel, required this.userName});

  final String monthLabel;
  final String userName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(monthLabel, style: textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xs / 2),
              Semantics(
                header: true,
                child: Text('Hola, $userName 👋', style: textTheme.headlineSmall),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        // Sin acción por ahora: las notificaciones llegan en la Fase 6.
        AppIconButton(
          icon: Icons.notifications_none,
          tooltip: 'Notificaciones',
          onPressed: () {},
        ),
      ],
    );
  }
}

class _BudgetAlertBanner extends StatelessWidget {
  const _BudgetAlertBanner({required this.alert});

  final BudgetAlert alert;

  @override
  Widget build(BuildContext context) {
    final category = alert.category.label.toLowerCase();
    final description = alert.remaining >= 0
        ? 'Te quedan ${CurrencyFormatter.format(alert.remaining)} para fin de mes'
        : 'Superaste el límite por ${CurrencyFormatter.format(alert.remaining)}';

    return AppBanner(
      variant: AppBannerVariant.warning,
      title: 'Presupuesto de $category al ${alert.percent}%',
      description: description,
    );
  }
}

