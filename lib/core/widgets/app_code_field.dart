import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Código de verificación de [length] dígitos en casillas separadas
/// (docs/05 pantalla 3).
///
/// Las casillas solo dibujan los dígitos: la entrada la recibe un campo
/// invisible encima, que acepta solo números, el autocompletado del código
/// desde el correo o los SMS y el lector de pantalla.
class AppCodeField extends StatefulWidget {
  const AppCodeField({
    super.key,
    this.length = 6,
    this.controller,
    this.onChanged,
    this.onCompleted,
    this.errorText,
    this.enabled = true,
    this.semanticLabel = 'Código de verificación',
  });

  final int length;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  /// Se llama cuando se escribieron los [length] dígitos.
  final ValueChanged<String>? onCompleted;
  final String? errorText;
  final bool enabled;
  final String semanticLabel;

  @override
  State<AppCodeField> createState() => _AppCodeFieldState();
}

class _AppCodeFieldState extends State<AppCodeField> {
  TextEditingController? _ownController;
  final FocusNode _focusNode = FocusNode();

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(AppCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onTextChanged);
      _controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _ownController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  void _handleChanged(String value) {
    widget.onChanged?.call(value);
    if (value.length == widget.length) widget.onCompleted?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final code = _controller.text;
    final hasError = widget.errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 0; i < widget.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _CodeBox(
                        digit: i < code.length ? code[i] : '',
                        isActive:
                            _focusNode.hasFocus &&
                            i == code.length.clamp(0, widget.length - 1),
                        hasError: hasError,
                        enabled: widget.enabled,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Campo invisible que recibe la entrada sobre las casillas.
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                alwaysIncludeSemantics: true,
                child: Semantics(
                  label: widget.semanticLabel,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    onChanged: _handleChanged,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(widget.length),
                    ],
                    showCursor: false,
                    enableInteractiveSelection: false,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration.collapsed(hintText: ''),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.errorText!,
            style: textTheme.bodySmall?.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.digit,
    required this.isActive,
    required this.hasError,
    required this.enabled,
  });

  final String digit;
  final bool isActive;
  final bool hasError;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? AppColors.error
        : isActive
        ? AppColors.primary
        : AppColors.border;

    return Container(
      height: AppSizes.codeBoxHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? AppColors.surface : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: borderColor,
          width: isActive || hasError
              ? AppSizes.borderWidthSelected
              : AppSizes.borderWidth,
        ),
      ),
      child: Text(digit, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
