import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_field_label.dart';

/// Campo de texto con la etiqueta en mayúsculas arriba.
///
/// [errorText] se muestra debajo en rojo. Con [isPassword] oculta lo escrito
/// y agrega un botón de ojo para mostrarlo. [trailing] se ubica a la derecha
/// de la etiqueta, por ejemplo un enlace "¿Olvidaste tu contraseña?".
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.errorText,
    this.isPassword = false,
    this.trailing,
    this.enabled = true,
    this.maxLength,
    this.autofillHints,
    this.onSubmitted,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? errorText;
  final bool isPassword;
  final Widget? trailing;
  final bool enabled;

  /// Máximo de caracteres; muestra el contador debajo del campo.
  final int? maxLength;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  // Con trailing, la etiqueta ocupa como máximo esta fracción del ancho,
  // para que el enlace siempre tenga espacio.
  static const double _labelMaxFractionWithTrailing = 0.6;

  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final obscure = widget.isPassword && _obscured;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // La etiqueta conserva su ancho natural en una sola línea; solo si no
        // cabe se reduce (nunca se parte). El trailing usa el espacio restante
        // y puede pasar a dos líneas.
        LayoutBuilder(
          builder: (context, constraints) {
            final maxLabelWidth = widget.trailing == null
                ? constraints.maxWidth
                : constraints.maxWidth * _labelMaxFractionWithTrailing;
            return Row(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxLabelWidth),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: AppFieldLabel(widget.label),
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: widget.trailing,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: widget.controller,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          maxLength: widget.maxLength,
          autofillHints: widget.autofillHints,
          enabled: widget.enabled,
          keyboardType: widget.isPassword
              ? TextInputType.visiblePassword
              : widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: obscure,
          enableSuggestions: !widget.isPassword,
          autocorrect: !widget.isPassword,
          style: textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.errorText,
            suffixIcon: widget.isPassword
                ? IconButton(
                    tooltip: obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: AppSizes.iconMd,
                      color: AppColors.textSecondary,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
