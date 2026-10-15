import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import 'simulator_state.dart';
import 'simulator_view_model.dart';

/// Aviso obligatorio del simulador (RF-43).
const String simulatorDisclaimer =
    'Simulación estimada con tasa del 7% EA. No constituye asesoría financiera.';

/// "1 año" o "N años".
String yearsLabel(int years) => years == 1 ? '1 año' : '$years años';

/// Simulador de ahorro (pantalla 9, fig. 5.9 y 5.10).
class SimulatorScreen extends ConsumerWidget {
  const SimulatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(simulatorViewModelProvider);

    final content = switch (state) {
      SimulatorLoading() => const Center(child: CircularProgressIndicator()),
      SimulatorError(:final message) => ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          AppBanner(
            variant: AppBannerVariant.error,
            title: 'No pudimos calcular tu ahorro',
            description: message,
          ),
        ],
      ),
      SimulatorNoData() => const _MessageView(
        icon: Icons.hourglass_empty,
        title: 'Necesitamos al menos un mes de datos para calcular tu ahorro',
        description:
            'Sigue registrando tus ingresos y gastos. Con tu primer mes '
            'completo podrás ver cuánto podrías acumular.',
      ),
      SimulatorNotSaving(:final periodLabel) => _MessageView(
        icon: Icons.savings_outlined,
        title: 'Aún no podemos proyectar tu ahorro',
        description:
            'Entre $periodLabel tus gastos fueron iguales o mayores que tus '
            'ingresos, así que tu ahorro promedio no es positivo. Cuando '
            'ahorres parte de tus ingresos, aquí verás cuánto podrías acumular.',
      ),
      SimulatorData() => _SimulatorDataView(data: state),
    };

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Encabezado fijo, como en el boceto: el contenido se desplaza debajo.
            const _Header(),
            Expanded(child: content),
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
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.screenPadding,
        AppSpacing.screenPadding,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text('Simulador de ahorro', style: textTheme.headlineSmall),
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(
            'Basado en tu ritmo real de los últimos 3 meses',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Estados sin proyección (RF-39): mensaje explicativo y aviso final.
class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        AppSpacing.xl,
      ),
      children: [
        AppCard(
          child: AppEmptyState(
            icon: icon,
            title: title,
            description: description,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _Disclaimer(),
      ],
    );
  }
}

class _SimulatorDataView extends ConsumerWidget {
  const _SimulatorDataView({required this.data});

  final SimulatorData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(simulatorViewModelProvider.notifier);
    final projection = data.projection;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        AppSpacing.xl,
      ),
      children: [
        AppSummaryCard(
          label: 'Ahorras en promedio',
          value: '${CurrencyFormatter.format(data.averageSavings)} / mes',
          caption: data.periodLabel,
        ),
        const SizedBox(height: AppSpacing.lg),
        _HorizonCard(years: data.years, onChanged: viewModel.setYears),
        const SizedBox(height: AppSpacing.lg),
        _ContributionCard(
          amount: data.monthlyContribution,
          onDecrease: data.canDecrease ? viewModel.decreaseContribution : null,
          onIncrease: viewModel.increaseContribution,
        ),
        const SizedBox(height: AppSpacing.lg),
        _ResultCards(
          withoutInterest: AppStatCard(
            label: 'Sin interés',
            value: CurrencyFormatter.format(projection.withoutInterest),
            description: 'Ahorro simple',
          ),
          withInterest: AppStatCard(
            label: 'Con interés',
            value: CurrencyFormatter.format(projection.withInterest),
            description: '7% EA estimado',
            highlight:
                '+${CurrencyFormatter.format(projection.interest)} en intereses',
            highlighted: true,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSectionHeader(title: 'Proyección año a año'),
              const SizedBox(height: AppSpacing.lg),
              AppBarComparisonChart(
                secondaryLabel: 'Sin interés',
                primaryLabel: 'Con interés (7% EA)',
                groups: [
                  for (final year in data.yearlySeries)
                    AppBarGroup(
                      label: 'A${year.years}',
                      secondary: year.withoutInterest,
                      primary: year.withInterest,
                      semanticLabel:
                          'Año ${year.years}: sin interés '
                          '${CurrencyFormatter.format(year.withoutInterest)}, '
                          'con interés '
                          '${CurrencyFormatter.format(year.withInterest)}',
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppBanner(
          variant: AppBannerVariant.warning,
          icon: Icons.lightbulb_outline,
          title:
              '¿Y si ahorras ${CurrencyFormatter.format(data.contributionStep)} '
              'más al mes?',
          description:
              'Llegarías a '
              '${CurrencyFormatter.format(data.boostedProjection.withInterest)} '
              'en ${yearsLabel(data.years)} con interés — '
              '${CurrencyFormatter.format(data.boostDifference)} más.',
        ),
        const SizedBox(height: AppSpacing.lg),
        const _Disclaimer(),
      ],
    );
  }
}

class _HorizonCard extends StatelessWidget {
  const _HorizonCard({required this.years, required this.onChanged});

  final int years;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text('Horizonte de tiempo', style: textTheme.titleMedium),
              ),
              const SizedBox(width: AppSpacing.sm),
              ExcludeSemantics(
                child: Text(
                  yearsLabel(years),
                  style: textTheme.headlineSmall?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Slider(
            value: years.toDouble(),
            min: simulatorMinYears.toDouble(),
            max: simulatorMaxYears.toDouble(),
            divisions: simulatorMaxYears - simulatorMinYears,
            semanticFormatterCallback: (value) =>
                'Horizonte de ${yearsLabel(value.round())}',
            onChanged: (value) => onChanged(value.round()),
          ),
          ExcludeSemantics(
            child: Row(
              children: [
                Text(yearsLabel(simulatorMinYears), style: textTheme.bodySmall),
                const Spacer(),
                Text(yearsLabel(simulatorMaxYears), style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContributionCard extends StatelessWidget {
  const _ContributionCard({
    required this.amount,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int amount;
  final VoidCallback? onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppFieldLabel('Aporte mensual'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              AppIconButton(
                icon: Icons.remove,
                tooltip: 'Disminuir aporte',
                onPressed: onDecrease,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  label: 'Aporte mensual',
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      CurrencyFormatter.format(amount),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AppIconButton(
                icon: Icons.add,
                tooltip: 'Aumentar aporte',
                onPressed: onIncrease,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tarjetas de resultado lado a lado; se apilan si no caben.
class _ResultCards extends StatelessWidget {
  const _ResultCards({required this.withoutInterest, required this.withInterest});

  final Widget withoutInterest;
  final Widget withInterest;

  // Ancho mínimo de cada tarjeta lado a lado, antes de escalar el texto.
  static const double _minCardWidth = 140;

  @override
  Widget build(BuildContext context) {
    final minCardWidth = MediaQuery.textScalerOf(context).scale(_minCardWidth);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < minCardWidth * 2 + AppSpacing.md) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              withoutInterest,
              const SizedBox(height: AppSpacing.md),
              withInterest,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: withoutInterest),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: withInterest),
            ],
          ),
        );
      },
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Text(
      simulatorDisclaimer,
      style: Theme.of(context).textTheme.bodySmall,
      textAlign: TextAlign.center,
    );
  }
}
