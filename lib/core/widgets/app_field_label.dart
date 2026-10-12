import 'package:flutter/material.dart';

/// Etiqueta de campo en mayúsculas, como "CORREO ELECTRÓNICO".
class AppFieldLabel extends StatelessWidget {
  const AppFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall,
      maxLines: 1,
      softWrap: false,
    );
  }
}
