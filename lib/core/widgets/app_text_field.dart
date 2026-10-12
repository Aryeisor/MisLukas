import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

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

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final obscure = widget.isPassword && _obscured;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // La etiqueta conserva su ancho natural en una sola línea;
        // el trailing usa el espacio restante y puede partirse en dos líneas.
        Row(
          children: [
            Text(
              widget.label.toUpperCase(),
              style: textTheme.labelSmall,
              maxLines: 1,
              softWrap: false,
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
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: widget.controller,
          onChanged: widget.onChanged,
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
