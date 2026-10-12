import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Fragmento del texto de [AppCheckboxTile]. Con [onTap] se muestra como enlace.
class AppTextSegment {
  const AppTextSegment(this.text, {this.onTap});

  final String text;
  final VoidCallback? onTap;
}

/// Casilla de verificación con un texto que puede incluir enlaces,
/// como "Acepto los Términos y la Política…".
class AppCheckboxTile extends StatefulWidget {
  const AppCheckboxTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.segments,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final List<AppTextSegment> segments;

  @override
  State<AppCheckboxTile> createState() => _AppCheckboxTileState();
}

class _AppCheckboxTileState extends State<AppCheckboxTile> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  TapGestureRecognizer _linkRecognizer(VoidCallback onTap) {
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final baseStyle = textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );
    final linkStyle = baseStyle?.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
    );

    // Los recognizers se recrean en cada build para reflejar los callbacks actuales.
    _disposeRecognizers();
    final spans = [
      for (final segment in widget.segments)
        if (segment.onTap == null)
          TextSpan(text: segment.text)
        else
          TextSpan(
            text: segment.text,
            style: linkStyle,
            recognizer: _linkRecognizer(segment.onTap!),
          ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // El Checkbox de Material ya ocupa 48 dp de área táctil.
        Checkbox(
          value: widget.value,
          onChanged: widget.onChanged == null
              ? null
              : (checked) => widget.onChanged!(checked ?? false),
          semanticLabel: widget.segments.map((s) => s.text).join(),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text.rich(TextSpan(style: baseStyle, children: spans)),
          ),
        ),
      ],
    );
  }
}

