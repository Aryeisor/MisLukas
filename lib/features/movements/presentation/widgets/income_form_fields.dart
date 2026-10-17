import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/movement_text.dart';

/// Antigüedad máxima de la fecha de un ingreso en el calendario.
const int incomeDateMaxYearsBack = 5;

/// Campos del formulario de un ingreso: valor, descripción y, si se recibe
/// [date], la fecha. Se usa en Nuevo movimiento, al editar un ingreso y en la
/// bienvenida (sin fecha: los ingresos se registran con la fecha de hoy).
class IncomeFormFields extends StatelessWidget {
  const IncomeFormFields({
    super.key,
    required this.amount,
    required this.onAmountChanged,
    required this.description,
    required this.onDescriptionChanged,
    this.date,
    this.today,
    this.onDateChanged,
    this.trailing,
  }) : assert(
         date == null || (today != null && onDateChanged != null),
         'La fecha necesita "hoy" y onDateChanged',
       );

  final int? amount;
  final ValueChanged<int?> onAmountChanged;
  final String description;
  final ValueChanged<String> onDescriptionChanged;
  final DateTime? date;

  /// Último día que se puede elegir (no se aceptan fechas futuras).
  final DateTime? today;
  final ValueChanged<DateTime>? onDateChanged;

  /// Acción junto al valor, por ejemplo "Quitar ingreso" en la bienvenida.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final amountField = AppAmountField(
      label: 'Valor del ingreso',
      initialValue: amount,
      onChanged: onAmountChanged,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing == null)
                amountField
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: amountField),
                    const SizedBox(width: AppSpacing.sm),
                    trailing!,
                  ],
                ),
              const SizedBox(height: AppSpacing.lg),
              _DescriptionField(
                initialValue: description,
                onChanged: onDescriptionChanged,
              ),
            ],
          ),
        ),
        if (date != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: _DateField(
              date: date!,
              today: today!,
              onChanged: onDateChanged!,
            ),
          ),
        ],
      ],
    );
  }
}

class _DescriptionField extends StatefulWidget {
  const _DescriptionField({
    required this.initialValue,
    required this.onChanged,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_DescriptionField> createState() => _DescriptionFieldState();
}

class _DescriptionFieldState extends State<_DescriptionField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: 'Descripción',
      hint: 'Ej: Salario, Prima, Freelance',
      controller: _controller,
      maxLength: movementTextMaxLength,
      textInputAction: TextInputAction.done,
      onChanged: widget.onChanged,
    );
  }
}

/// Fecha del ingreso: un botón con el día elegido que abre el calendario del
/// sistema, hasta hoy.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.date,
    required this.today,
    required this.onChanged,
  });

  final DateTime date;
  final DateTime today;
  final ValueChanged<DateTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date.isAfter(today) ? today : date,
      firstDate: DateTime(today.year - incomeDateMaxYearsBack),
      lastDate: today,
      helpText: 'Fecha del ingreso',
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final label = DateLabels.longDay(date, today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppFieldLabel('Fecha'),
        const SizedBox(height: AppSpacing.sm),
        // La tarjeta une esta etiqueta con "FECHA": el lector dice "Fecha,
        // Hoy, 22 de septiembre, botón, toca para cambiarla".
        Semantics(
          label: label,
          hint: 'Toca para cambiarla',
          button: true,
          excludeSemantics: true,
          onTap: () => _pick(context),
          child: AppSecondaryButton(
            label: label,
            icon: Icons.calendar_today_outlined,
            onPressed: () => _pick(context),
          ),
        ),
      ],
    );
  }
}
