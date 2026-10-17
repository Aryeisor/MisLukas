import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/widgets.dart';

/// Antigüedad máxima de la fecha de un movimiento en el calendario.
const int movementDateMaxYearsBack = 5;

/// Fecha de un gasto o un ingreso (RF-19): la etiqueta "FECHA" y un botón con
/// el día elegido ("Hoy, 17 de octubre") que abre el calendario del sistema,
/// hasta hoy. No se pueden elegir fechas futuras.
class MovementDateField extends StatelessWidget {
  const MovementDateField({
    super.key,
    required this.date,
    required this.today,
    required this.onChanged,
    required this.pickerTitle,
  });

  final DateTime date;

  /// Último día que se puede elegir.
  final DateTime today;
  final ValueChanged<DateTime> onChanged;

  /// Título del calendario: "Fecha del gasto" o "Fecha del ingreso".
  final String pickerTitle;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date.isAfter(today) ? today : date,
      firstDate: DateTime(today.year - movementDateMaxYearsBack),
      lastDate: today,
      helpText: pickerTitle,
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
