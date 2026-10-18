import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/category_style.dart';
import '../../utils/validators.dart';
import '../widgets.dart';
import 'demo_data_actions.dart';
import 'sample_receipt_image.dart';

/// Galería de componentes para revisar sus estados. Solo se registra en modo debug.
class ComponentGalleryScreen extends StatefulWidget {
  const ComponentGalleryScreen({super.key});

  @override
  State<ComponentGalleryScreen> createState() => _ComponentGalleryScreenState();
}

class _ComponentGalleryScreenState extends State<ComponentGalleryScreen> {
  int _tabIndex = 0;
  bool _photoSelected = true;
  CategoryKind _category = CategoryKind.mercado;
  int? _amount = 87400;
  bool _acceptedTerms = false;
  late final Future<(Uint8List, Rect)> _sampleReceipt = drawSampleReceipt(
    Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
  );

  static const _chipCategories = [
    CategoryKind.mercado,
    CategoryKind.transporte,
    CategoryKind.ocio,
    CategoryKind.servicios,
    CategoryKind.restaurantes,
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Componentes')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const AppOfflineIndicator(),
          const SizedBox(height: AppSpacing.xl),
          // Solo en modo desarrollo, como toda la galería.
          const DemoDataActions(),
          _section('Botones'),
          AppPrimaryButton(label: 'Iniciar sesión', onPressed: () {}),
          _gap,
          AppPrimaryButton(
            label: 'Nuevo gasto',
            icon: Icons.add,
            onPressed: () {},
          ),
          _gap,
          const AppPrimaryButton(
            label: 'Guardar gasto',
            onPressed: null,
            isLoading: true,
          ),
          _gap,
          const AppPrimaryButton(label: 'Crear cuenta', onPressed: null),
          _gap,
          AppSecondaryButton(label: 'Usar PIN', onPressed: () {}),
          _gap,
          AppSecondaryButton(
            label: 'Eliminar movimiento',
            icon: Icons.delete_outline,
            destructive: true,
            onPressed: () => showAppConfirmDialog(
              context,
              title: '¿Eliminar este movimiento?',
              message: 'Esta acción no se puede deshacer.',
              confirmLabel: 'Eliminar',
              destructive: true,
            ),
          ),
          _gap,
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppSecondaryButton(
                  label: 'Google',
                  icon: Icons.g_mobiledata,
                  onPressed: null,
                  badge: 'Próximamente',
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppSecondaryButton(
                  label: 'Apple',
                  icon: Icons.apple,
                  onPressed: null,
                  badge: 'Próximamente',
                ),
              ),
            ],
          ),

          _section('Campos'),
          const AppTextField(
            label: 'Correo electrónico',
            hint: 'tucorreo@ejemplo.com',
            keyboardType: TextInputType.emailAddress,
          ),
          _gap,
          const AppTextField(
            label: 'Correo electrónico',
            hint: 'tucorreo@ejemplo.com',
            errorText: 'Ingresa un correo válido',
          ),
          _gap,
          AppTextField(
            label: 'Contraseña',
            isPassword: true,
            trailing: TextButton(
              onPressed: () {},
              child: const Text('¿Olvidaste tu contraseña?'),
            ),
          ),
          _gap,
          AppAmountField(
            label: 'Valor detectado',
            initialValue: _amount,
            onChanged: (value) => setState(() => _amount = value),
          ),
          _gap,
          Text(
            'Valor entregado: ${_amount ?? '—'}',
            style: textTheme.bodySmall,
          ),

          _section('Íconos de categoría'),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final kind in CategoryKind.values) CategoryIcon(kind: kind),
            ],
          ),

          _section('Movimientos'),
          const MovementTile(
            title: 'Éxito',
            category: CategoryKind.mercado,
            dateLabel: 'Hoy',
            amount: 87400,
          ),
          _gap,
          const MovementTile(
            title: 'TransMilenio',
            category: CategoryKind.transporte,
            dateLabel: 'Ayer',
            amount: 5600,
          ),
          _gap,
          const MovementTile(
            title: 'Salario',
            category: CategoryKind.ingreso,
            dateLabel: 'Sep 1',
            amount: 3800000,
          ),
          _gap,
          MovementTile(
            title: 'Juan Valdez',
            category: CategoryKind.ocio,
            dateLabel: 'Sep 1',
            amount: 18500,
            isPendingSync: true,
            onTap: () {},
          ),

          _section('Tarjetas seleccionables'),
          SelectableOptionCard(
            icon: Icons.photo_camera_outlined,
            title: 'Foto del recibo',
            description: 'La app extrae el valor y sugiere la categoría automáticamente.',
            badge: 'Recomendado',
            selected: _photoSelected,
            onTap: () => setState(() => _photoSelected = true),
          ),
          _gap,
          SelectableOptionCard(
            icon: Icons.edit_outlined,
            title: 'Registro manual',
            description: 'Escribe el valor y elige la categoría tú mismo.',
            selected: !_photoSelected,
            onTap: () => setState(() => _photoSelected = false),
          ),

          _section('Chips'),
          AppChipGroup<CategoryKind>(
            options: _chipCategories,
            selected: _category,
            labelBuilder: (kind) => kind.label,
            onSelected: (kind) => setState(() => _category = kind),
          ),

          _section('Banners'),
          const AppBanner(
            variant: AppBannerVariant.warning,
            title: 'Presupuesto de mercado al 78%',
            description: r'Te quedan $253.000 para fin de mes',
          ),
          _gap,
          const AppBanner(
            variant: AppBannerVariant.success,
            title: 'Recibo leído correctamente',
            description: 'Revisa y ajusta si necesitas.',
          ),
          _gap,
          const AppBanner(
            variant: AppBannerVariant.error,
            title: 'Correo o contraseña incorrectos',
            description: 'Revisa tus datos e inténtalo de nuevo.',
          ),
          _gap,
          const AppBanner(
            variant: AppBannerVariant.info,
            title: 'Simulación estimada con tasa del 7% EA.',
            description: 'No constituye asesoría financiera.',
          ),

          _section('Selector de pestañas'),
          AppSegmentedTabs(
            labels: const ['Iniciar sesión', 'Registrarse'],
            selectedIndex: _tabIndex,
            onChanged: (index) => setState(() => _tabIndex = index),
          ),

          _section('Estado vacío'),
          AppCard(
            child: AppEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Aún no tienes movimientos este mes',
              description: 'Registra tu primer gasto para empezar.',
              actionLabel: 'Registrar gasto',
              onAction: () {},
            ),
          ),

          _section('Tarjeta de resumen'),
          const AppSummaryCard(
            label: 'Disponible este mes',
            value: r'$1.874.320',
            items: [
              AppSummaryItem(
                icon: Icons.arrow_upward,
                label: 'Ingresos',
                value: r'$4.250.000',
              ),
              AppSummaryItem(
                icon: Icons.arrow_downward,
                label: 'Gastos',
                value: r'$2.375.680',
              ),
            ],
          ),
          _gap,
          const AppSummaryCard(
            label: 'Ahorro promedio',
            value: r'$420.000 / mes',
            caption: 'Calculado entre julio y septiembre de 2026',
          ),

          _section('Gráficos'),
          Center(
            child: AppDonutChart(
              segments: [
                for (final (kind, value) in const [
                  (CategoryKind.mercado, 38),
                  (CategoryKind.ocio, 22),
                  (CategoryKind.transporte, 18),
                  (CategoryKind.servicios, 13),
                  (CategoryKind.otros, 9),
                ])
                  AppChartSegment(
                    value: value,
                    color: kind.color,
                    label: '${kind.label} $value%',
                  ),
              ],
              center: Text('Total', style: textTheme.bodySmall),
            ),
          ),
          _gap,
          const AppLegendItem(
            color: AppColors.categoryMercado,
            label: 'Mercado',
            value: '38%',
            prominent: true,
          ),
          _gap,
          const AppVariationBar(fraction: 0.4, color: AppColors.error),
          _gap,
          const AppVariationBar(fraction: 0.25, color: AppColors.success),
          _gap,
          const AppBarComparisonChart(
            secondaryLabel: 'Sin interés',
            primaryLabel: 'Con interés (7% EA)',
            groups: [
              AppBarGroup(
                label: 'A1',
                secondary: 5040000,
                primary: 5199725,
                semanticLabel: 'Año 1',
              ),
              AppBarGroup(
                label: 'A2',
                secondary: 10080000,
                primary: 10763430,
                semanticLabel: 'Año 2',
              ),
              AppBarGroup(
                label: 'A3',
                secondary: 15120000,
                primary: 16716595,
                semanticLabel: 'Año 3',
              ),
            ],
          ),

          _section('Tarjetas de resultado'),
          const AppStatCard(
            label: 'Sin interés',
            value: r'$15.120.000',
            description: 'Ahorro simple',
          ),
          _gap,
          const AppStatCard(
            label: 'Con interés',
            value: r'$16.716.595',
            description: '7% EA estimado',
            highlight: r'+$1.596.595 en intereses',
            highlighted: true,
          ),

          _section('Avatar'),
          const Center(child: AppAvatar(initials: 'CR')),

          _section('Botón de ícono'),
          Row(
            children: [
              AppIconButton(
                icon: Icons.notifications_none,
                tooltip: 'Notificaciones',
                onPressed: () {},
              ),
              const SizedBox(width: AppSpacing.md),
              AppIconButton(
                icon: Icons.close,
                tooltip: 'Cerrar',
                onPressed: () {},
              ),
              const SizedBox(width: AppSpacing.md),
              AppIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Volver',
                onPressed: () {},
              ),
            ],
          ),

          _section('Contraseña y casilla'),
          const AppPasswordStrength(
            strength: PasswordStrength.medium,
            requirements: [
              AppRequirement(label: 'Mínimo 8 caracteres', met: true),
              AppRequirement(label: 'Una mayúscula', met: true),
              AppRequirement(label: 'Un número', met: true),
              AppRequirement(label: 'Un símbolo', met: false),
            ],
          ),
          _gap,
          AppCheckboxTile(
            value: _acceptedTerms,
            onChanged: (value) => setState(() => _acceptedTerms = value),
            segments: [
              const AppTextSegment('Acepto los '),
              AppTextSegment('Términos', onTap: () {}),
              const AppTextSegment(' y la '),
              AppTextSegment(
                'Política de tratamiento de datos personales',
                onTap: () {},
              ),
              const AppTextSegment(' (Ley 1581 de 2012)'),
            ],
          ),

          _section('Código de verificación'),
          const AppCodeField(),
          _gap,
          const AppCodeField(errorText: 'El código no es válido o ya venció.'),

          _section('Recibo'),
          FutureBuilder(
            future: _sampleReceipt,
            builder: (context, snapshot) {
              final sample = snapshot.data;
              if (sample == null) return const ReceiptPreview.loading();
              final (bytes, totalRow) = sample;
              return ReceiptPreview.image(bytes, detectedArea: totalRow);
            },
          ),
          _gap,
          const ReceiptPreview.unavailable(
            ReceiptPreviewUnavailable.notOnDevice,
          ),
          _gap,
          const ReceiptPreview.unavailable(
            ReceiptPreviewUnavailable.unreadable,
          ),

          _section('Snackbar'),
          Row(
            children: [
              Expanded(
                child: AppSecondaryButton(
                  label: 'Éxito',
                  onPressed: () =>
                      AppSnackbar.success(context, 'Gasto guardado'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppSecondaryButton(
                  label: 'Error',
                  onPressed: () =>
                      AppSnackbar.error(context, 'No pudimos guardar el gasto'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  static const Widget _gap = SizedBox(height: AppSpacing.md);

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
      child: AppSectionHeader(title: title),
    );
  }
}
