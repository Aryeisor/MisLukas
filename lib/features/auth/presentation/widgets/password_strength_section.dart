import 'package:flutter/material.dart';

import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/widgets.dart';

/// Fortaleza y requisitos de [password] (RF-02), usados en el registro y en la
/// contraseña nueva de la recuperación.
class PasswordStrengthSection extends StatelessWidget {
  const PasswordStrengthSection({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final requirements = PasswordRequirements.check(password);
    return AppPasswordStrength(
      strength: passwordStrength(password),
      requirements: [
        AppRequirement(
          label: 'Mínimo $passwordMinLength caracteres',
          met: requirements.minLength,
        ),
        AppRequirement(label: 'Una mayúscula', met: requirements.hasUppercase),
        AppRequirement(label: 'Un número', met: requirements.hasNumber),
        AppRequirement(label: 'Un símbolo', met: requirements.hasSymbol),
      ],
    );
  }
}
