import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// Pantalla provisional de simulador de ahorro. La real se construye en la Fase 3.
class SimulatorScreen extends StatelessWidget {
  const SimulatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Text('Simulador de ahorro', style: Theme.of(context).textTheme.headlineSmall),
        ),
      ),
    );
  }
}
