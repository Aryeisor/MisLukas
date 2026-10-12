import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/currency_formatter.dart';

/// Línea de un recibo: producto y precio.
class ReceiptLine {
  const ReceiptLine(this.label, this.amount);

  final String label;
  final int amount;
}

/// Vista previa de un recibo sobre fondo oscuro, con la línea del total
/// resaltada como "Área detectada". En la Fase 6 se mostrará la foto real.
class ReceiptPreview extends StatelessWidget {
  const ReceiptPreview({
    super.key,
    required this.merchant,
    required this.taxId,
    required this.lines,
    required this.total,
  });

  final String merchant;

  /// NIT del comercio, por ejemplo "890.900.608-9".
  final String taxId;
  final List<ReceiptLine> lines;
  final int total;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lineStyle = textTheme.bodySmall?.copyWith(
      color: AppColors.textPrimary,
    );

    return Semantics(
      label: 'Vista previa del recibo de $merchant',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.action,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Column(
            children: [
              Text(
                merchant,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs / 2),
              Text(
                'NIT $taxId',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall,
              ),
              const Divider(height: AppSpacing.lg),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xs / 2,
                  ),
                  child: _LineRow(
                    label: line.label,
                    amount: line.amount,
                    style: lineStyle,
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              _DetectedTotal(total: total, style: lineStyle),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.label, required this.amount, this.style});

  final String label;
  final int amount;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: style)),
        const SizedBox(width: AppSpacing.sm),
        Text(CurrencyFormatter.format(amount), style: style),
      ],
    );
  }
}

/// Línea del total con borde azul y la etiqueta "Área detectada".
class _DetectedTotal extends StatelessWidget {
  const _DetectedTotal({required this.total, this.style});

  final int total;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final boldStyle = style?.copyWith(fontWeight: FontWeight.w700);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: AppColors.primary,
              width: AppSizes.borderWidthSelected,
            ),
          ),
          child: _LineRow(label: 'TOTAL', amount: total, style: boldStyle),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs / 2,
          ),
          decoration: const ShapeDecoration(
            color: AppColors.primary,
            shape: StadiumBorder(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.circle,
                size: AppSizes.iconXs / 2,
                color: AppColors.surface,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  'Área detectada',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.surface,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
