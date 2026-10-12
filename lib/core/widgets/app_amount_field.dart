import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/currency_formatter.dart';
import 'app_field_label.dart';

/// Campo grande para montos en pesos: solo dígitos, con puntos de miles
/// mientras se escribe. Entrega el valor como int (null si está vacío).
class AppAmountField extends StatefulWidget {
  const AppAmountField({
    super.key,
    this.label,
    this.initialValue,
    this.onChanged,
    this.errorText,
    this.autofocus = false,
  });

  final String? label;
  final int? initialValue;
  final ValueChanged<int?>? onChanged;
  final String? errorText;
  final bool autofocus;

  /// Máximo de dígitos aceptados, para no desbordar el int.
  static const int maxDigits = 12;

  @override
  State<AppAmountField> createState() => _AppAmountFieldState();
}

class _AppAmountFieldState extends State<AppAmountField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue == null
        ? ''
        : CurrencyFormatter.formatDigits(widget.initialValue!),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final amountStyle = textTheme.headlineLarge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          AppFieldLabel(widget.label!),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextField(
          controller: _controller,
          autofocus: widget.autofocus,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(AppAmountField.maxDigits),
            _ThousandsSeparatorFormatter(),
          ],
          style: amountStyle,
          onChanged: (text) => widget.onChanged?.call(
            CurrencyFormatter.parse(text),
          ),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: amountStyle?.copyWith(color: AppColors.disabled),
            errorText: widget.errorText,
            // prefixIcon se ve siempre; prefixText solo con foco o con texto.
            prefixIcon: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.sm,
              ),
              child: Text(
                '\$',
                style: amountStyle,
                semanticsLabel: 'pesos',
              ),
            ),
            prefixIconConstraints: const BoxConstraints(),
          ),
        ),
      ],
    );
  }
}

/// Formatea los dígitos con punto de miles y deja el cursor al final.
class _ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final value = CurrencyFormatter.parse(newValue.text);
    if (value == null) return TextEditingValue.empty;

    final text = CurrencyFormatter.formatDigits(value);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
