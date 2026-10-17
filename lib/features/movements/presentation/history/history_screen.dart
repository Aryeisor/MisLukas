import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/error_messages.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/sync/sync_controller.dart';
import '../../../../core/sync/sync_status.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/category_mapping.dart';
import '../../../../core/theme/category_style.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/utils_providers.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/month_summary.dart';
import '../../domain/entities/movement.dart';
import '../../domain/usecases/watch_movement_history.dart';
import '../confirm_movement_view_model.dart';
import 'history_view_model.dart';

/// Historial de movimientos (RF-22, pantalla 12): agrupado por mes, del más
/// reciente al más antiguo, con filtro por tipo y por categoría.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyViewModelProvider);
    final viewModel = ref.read(historyViewModelProvider.notifier);
    final page = state.page;
    final value = page.value;

    final Widget content;
    if (page.hasError) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: const [
          AppBanner(
            variant: AppBannerVariant.error,
            title: 'No pudimos cargar tu historial',
            description: dataLoadErrorMessage,
          ),
        ],
      );
    } else if (value == null) {
      content = const Center(child: CircularProgressIndicator());
    } else if (value.isEmpty) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          if (state.filter.isEmpty)
            AppEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Aún no tienes movimientos',
              description:
                  'Registra tu primer gasto o ingreso para verlo aquí.',
              actionLabel: 'Registrar un movimiento',
              onAction: () => context.push(AppRoutes.newMovement),
            )
          else
            const AppEmptyState(
              icon: Icons.filter_list_off,
              title: 'No hay movimientos con este filtro',
              description: 'Prueba con otro tipo o categoría.',
            ),
        ],
      );
    } else {
      content = _HistoryList(
        page: value,
        type: state.type,
        today: ref.watch(clockProvider).today(),
        onLoadMore: viewModel.loadMore,
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.screenPadding,
                AppSpacing.screenPadding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Header(),
                  const SizedBox(height: AppSpacing.lg),
                  Semantics(
                    container: true,
                    label: 'Tipo de movimiento',
                    child: AppSegmentedTabs(
                      labels: [
                        for (final type in HistoryTypeFilter.values) type.label,
                      ],
                      selectedIndex: state.type.index,
                      onChanged: (index) =>
                          viewModel.selectType(HistoryTypeFilter.values[index]),
                    ),
                  ),
                  if (state.showsCategories) ...[
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      container: true,
                      label: 'Categoría',
                      child: AppChipGroup<CategoryKind?>(
                        options: const [null, ...expenseCategoryOptions],
                        selected: state.category,
                        labelBuilder: (category) => category?.label ?? 'Todas',
                        onSelected: viewModel.selectCategory,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
            Expanded(
              child: value == null && !page.hasError
                  ? content
                  : RefreshIndicator(
                      // Deslizar hacia abajo sincroniza, como en Inicio.
                      onRefresh: () =>
                          ref.read(syncControllerProvider.notifier).syncNow(),
                      child: content,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIconButton(
          icon: Icons.arrow_back,
          tooltip: 'Volver',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              'Historial',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
      ],
    );
  }
}

/// Lista perezosa: encabezado de cada mes, sus movimientos y, si hay meses
/// más antiguos, un indicador que pide cargarlos al aparecer.
class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.page,
    required this.type,
    required this.today,
    required this.onLoadMore,
  });

  final HistoryPage page;
  final HistoryTypeFilter type;
  final DateTime today;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final items = <Object>[
      for (final month in page.months) ...[month.summary, ...month.movements],
      if (page.hasMore) const _LoadMore(),
    ];

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        AppSpacing.xl,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return switch (item) {
          MonthSummary() => _MonthHeader(
            summary: item,
            type: type,
            isFirst: index == 0,
          ),
          Movement() => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: MovementTile(
              key: ValueKey(item.id),
              title: item.note ?? item.description,
              category: categoryKindForId(item.categoryId),
              dateLabel: DateLabels.relativeDay(item.date, today),
              amount: item.amount,
              isPendingSync: item.syncStatus != SyncStatus.synced,
              onTap: () => context.push(AppRoutes.editMovementWith(item.id)),
            ),
          ),
          _ => _LoadMoreIndicator(onVisible: onLoadMore),
        };
      },
    );
  }
}

/// Marca del final de la lista cuando hay meses más antiguos.
class _LoadMore {
  const _LoadMore();
}

/// Indicador al final de la lista: al construirse pide los meses siguientes.
class _LoadMoreIndicator extends StatefulWidget {
  const _LoadMoreIndicator({required this.onVisible});

  final VoidCallback onVisible;

  @override
  State<_LoadMoreIndicator> createState() => _LoadMoreIndicatorState();
}

class _LoadMoreIndicatorState extends State<_LoadMoreIndicator> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisible();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: CircularProgressIndicator(semanticsLabel: 'Cargando más meses'),
      ),
    );
  }
}

/// "Octubre 2026" y sus totales: "+$4.250.000 ingresos · -$2.375.680
/// gastos". Con un filtro de tipo, solo el total que aplica.
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.summary,
    required this.type,
    required this.isFirst,
  });

  final MonthSummary summary;
  final HistoryTypeFilter type;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final income =
        '${CurrencyFormatter.signed(summary.income, isIncome: true)} ingresos';
    final expenses =
        '${CurrencyFormatter.signed(summary.expenses, isIncome: false)} gastos';
    final totals = switch (type) {
      HistoryTypeFilter.all => '$income · $expenses',
      HistoryTypeFilter.expenses => expenses,
      HistoryTypeFilter.income => income,
    };

    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 0 : AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(title: DateLabels.monthYear(summary.month)),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(totals, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
