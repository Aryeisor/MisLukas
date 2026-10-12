import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// Pantalla provisional de perfil. La real se construye en la Fase 3.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Text('Perfil', style: Theme.of(context).textTheme.headlineSmall),
        ),
      ),
    );
  }
}
