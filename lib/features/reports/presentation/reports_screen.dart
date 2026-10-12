import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import 'reports_state.dart';
import 'reports_view_model.dart';

/// Pantalla de Reportes (pantalla 8, fig. 5.8).
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportsViewModelProvider);

    final content = switch (state) {
      ReportsLoading() => const Center(child: CircularProgressIndicator()),
      ReportsError(:final message) => ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          AppBanner(
            variant: AppBannerVariant.error,
            title: 'No pudimos cargar tus reportes',
            description: message,
          ),
        ],
      ),
      ReportsEmpty(:final monthLabel, :final monthName) => ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          _Header(monthLabel: monthLabel, monthName: monthName),
          const SizedBox(height: AppSpacing.xl),
          AppEmptyState(
            icon: Icons.pie_chart_outline,
            title: 'Aún no tienes gastos este mes',
            description:
                'Cuando registres tus gastos, aquí verás en qué se va tu dinero.',
            actionLabel: 'Registrar un gasto',
            onAction: () => context.push(AppRoutes.newMovement),
          ),
        ],
      ),
      ReportsData() => _ReportsDataView(data: state),
    };

    return Scaffold(body: SafeArea(bottom: false, child: content));
  }
}

class _ReportsDataView extends StatelessWidget {
  const _ReportsDataView({required this.data});

  final ReportsData data;

  @override
  Widget build(BuildContext context) {
    final comparison = data.comparison;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.screenPadding,
        AppSpacing.screenPadding,
        AppSpacing.xl,
      ),
      children: [
        _Header(
          monthLabel: data.monthLabel,
          monthName: data.monthName,
          total: data.total,
        ),
        const SizedBox(height: AppSpacing.xl),
        _CategoryCard(data: data),
        if (comparison != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _ComparisonCard(comparison: comparison),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.monthLabel,
    required this.monthName,
    this.total,
  });

  final String monthLabel;
  final String monthName;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(monthLabel, style: textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xs / 2),
        Semantics(
          header: true,
          child: Text(
            'Tus gastos de $monthName',
            style: textTheme.headlineSmall,
          ),
        ),
        if (total != null) ...[
          const SizedBox(height: AppSpacing.sm),
          // El total se reduce en pantallas angostas en lugar de partirse.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              CurrencyFormatter.format(total!),
              style: textTheme.headlineLarge,
            ),
          ),
        ],
      ],
    );
  }
}

/// Tarjeta "Por categoría": dona y leyenda con porcentajes.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.data});

  final ReportsData data;

  // Ancho mínimo de la leyenda junto a la dona, antes de escalar el texto.
  static const double _legendMinWidth = 140;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final textScaler = MediaQuery.textScalerOf(context);

    final donut = AppDonutChart(
      semanticsPrefix: 'Gastos por categoría, ${data.shortMonthLabel}',
      segments: [
        for (final share in data.shares)
          AppChartSegment(
            value: share.amount,
            color: share.category.color,
            label: '${share.category.label} ${share.percent}%',
          ),
      ],
      center: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Total',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(data.shortMonthLabel, style: textTheme.bodySmall),
        ],
      ),
    );

    final legend = Column(
      children: [
        for (var i = 0; i < data.shares.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          AppLegendItem(
            color: data.shares[i].category.color,
            label: data.shares[i].category.label,
            value: '${data.shares[i].percent}%',
            prominent: true,
          ),
        ],
      ],
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: 'Por categoría'),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide =
                  constraints.maxWidth >=
                  AppSizes.donutSize +
                      AppSpacing.lg +
                      textScaler.scale(_legendMinWidth);
              if (sideBySide) {
                return Row(
                  children: [
                    donut,
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: legend),
                  ],
                );
              }
              return Column(
                children: [
                  donut,
                  const SizedBox(height: AppSpacing.lg),
                  legend,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Tarjeta "Vs. agosto 2026": variación por categoría frente al mes anterior.
class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.comparison});

  final MonthComparison comparison;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Vs. ${comparison.previousMonthLabel}'),
          const SizedBox(height: AppSpacing.lg),
          for (final item in comparison.items) ...[
            _VariationRow(
              item: item,
              previousMonthLabel: comparison.previousMonthLabel,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.xs),
          const Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              AppLegendItem(
                color: AppColors.error,
                label: 'Aumento',
                shape: AppLegendShape.square,
              ),
              AppLegendItem(
                color: AppColors.success,
                label: 'Reducción',
                shape: AppLegendShape.square,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VariationRow extends StatelessWidget {
  const _VariationRow({required this.item, required this.previousMonthLabel});

  final CategoryVariation item;
  final String previousMonthLabel;

  // Anchos de referencia de la fila en una línea, antes de escalar el texto.
  static const double _nameWidth = 110;
  static const double _percentMinWidth = 56;
  static const double _barMinWidth = 80;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final change = item.percentChange;
    final color = change > 0
        ? AppColors.error
        : change < 0
        ? AppColors.success
        : AppColors.textSecondary;
    // Signo explícito: la información no depende solo del color.
    final percentText = change > 0
        ? '+$change%'
        : change < 0
        ? '−${change.abs()}%'
        : '0%';
    final semanticChange = change > 0
        ? 'aumento del $change%'
        : change < 0
        ? 'reducción del ${change.abs()}%'
        : 'sin cambio';

    final bar = AppVariationBar(fraction: item.fraction, color: color);

    // Cada fila es un nodo propio para que el lector la anuncie por separado.
    return Semantics(
      container: true,
      label:
          '${item.category.label}, $semanticChange frente a $previousMonthLabel',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final nameWidth = textScaler.scale(_nameWidth);
          final percentWidth = textScaler.scale(_percentMinWidth);
          final oneLine =
              constraints.maxWidth >=
              nameWidth + _barMinWidth + percentWidth + AppSpacing.lg;

          if (!oneLine) {
            // En pantallas angostas: nombre y porcentaje arriba, barra debajo.
            return Column(
              children: [
                AppLegendItem(
                  color: item.category.color,
                  label: item.category.label,
                  value: percentText,
                  valueColor: color,
                  prominent: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                bar,
              ],
            );
          }

          return Row(
            children: [
              SizedBox(
                width: nameWidth,
                child: AppLegendItem(
                  color: item.category.color,
                  label: item.category.label,
                  prominent: true,
                ),
              ),
              Expanded(child: bar),
              const SizedBox(width: AppSpacing.lg),
              ConstrainedBox(
                constraints: BoxConstraints(minWidth: percentWidth),
                child: Text(
                  percentText,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
