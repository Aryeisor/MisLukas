# MisLukas

App móvil de finanzas personales para usuarios colombianos, desarrollada en Flutter como proyecto de la asignatura Diseño Móvil (Ingeniería de Software). Versión actual: **MVP**.

El usuario registra gastos e ingresos (por foto del recibo con OCR o de forma manual), ve en qué se va su dinero y proyecta su ahorro. "Lukas" es la forma coloquial de decir miles de pesos en Colombia.

Ciclo central del producto: **registrar → entender → proyectar**.

## Documentación del proyecto

La documentación técnica completa está en `docs/`. Es la **fuente de verdad** del proyecto. Antes de implementar algo, lee la sección relacionada:

| Archivo | Contenido |
|---|---|
| `docs/01-introduccion.md` | Qué es la app, propósito del documento, alcance del MVP |
| `docs/02-problema-justificacion.md` | Problema, solución, diferenciadores |
| `docs/03-usuarios.md` | Público objetivo, personas, escenarios, historias de usuario (HU-01 a HU-10) |
| `docs/04-requisitos.md` | Requisitos funcionales (RF-01 a RF-49) y no funcionales (RNF-01 a RNF-29) |
| `docs/05-diseno-ui.md` | Flujo de navegación, pantallas, estados, guía de estilo. Capturas de los bocetos en `docs/img/` |
| `docs/06-arquitectura.md` | Stack, capas, modelo de datos, almacenamiento, sincronización, Supabase |
| `docs/07-funciones-dispositivo.md` | Cámara, OCR, notificaciones, biometría, permisos |
| `docs/08-seguridad.md` | Autenticación, RLS, inyección SQL, protección local, Ley 1581 |

Si el código que vas a escribir contradice la documentación, **no lo resuelvas por tu cuenta**: avísame y explica la diferencia.

## Decisiones del proyecto

Decisiones tomadas durante el desarrollo que ajustan o precisan la documentación:

- La decisión de pantalla según la sesión se hace con un `redirect` de go_router (Fase 5), no con el widget `AuthGate` de docs/06 §6.7.2. La lógica es la misma: sin sesión → /login; con sesión → desbloqueo → /home.
- La pantalla de Inicio vive en `features/home/`, no en `features/movements/` como sugiere docs/06.
- Restaurantes usa #DB2777, color que no estaba en la guía 5.4.1.
- En `MovementTile`, un movimiento es ingreso si su categoría es `CategoryKind.ingreso`.
- La variante manual de Confirma los datos se titula "Registra tu gasto" (como en el diagrama 5.1), su campo es "VALOR DEL GASTO" y la sección "CATEGORÍA" no trae ninguna categoría preseleccionada, a diferencia del boceto 5.7.
- El cifrado de la base local usa SQLite3MultipleCiphers mediante los hooks del paquete `sqlite3` (`hooks > user_defines > sqlite3 > source: sqlite3mc` en pubspec.yaml) en lugar de SQLCipher, según la recomendación actual de Drift.
- La base local no guarda `usuario_id`: pertenece a un solo usuario y el `usuario_id` se agrega al sincronizar (Fase 5).
- Las categorías predeterminadas tienen UUID fijos (`DefaultCategory` en `features/budgets/domain/entities/default_categories.dart`), iguales en todos los dispositivos y en el servidor.
- PRAGMA key es la única sentencia SQL con el valor dentro del texto, porque SQLite no admite parámetros en ese comando; antes se valida que la clave tenga exactamente 64 caracteres hexadecimales.
- Los datos de demostración solo existen en modo desarrollo (`kDebugMode`): se cargan y se borran desde la galería y el Perfil con `DemoSeed` (`core/database/seed/demo_seed.dart`), con fechas relativas al reloj. En la versión de publicación la app arranca vacía y esas acciones no existen.
- Otros se agregó a las categorías seleccionables de un gasto (registro y edición), aunque el boceto 5.7 no la muestra, porque RF-27 la incluye. Al editar un ingreso solo se ofrece Ingreso; el tipo no cambia al editar.
- La verificación del correo al registrarse y la recuperación de contraseña usan un código de 6 dígitos escrito en la app (`verifyOTP`), no enlaces: no hay deep links (`detectSessionInUri: false`) ni cambios en `android/` o `ios/`. Las plantillas de correo de Supabase usan `{{ .Token }}`.
- La sesión de Supabase y el verificador PKCE se guardan en `flutter_secure_storage` (`SecureSessionStorage` y `SecurePkceStorage` en `core/security/secure_auth_storage.dart`), nunca en SharedPreferences. `Supabase.initialize` usa `debug: false` para que no escriba logs.
- `AuthRepository` ignora los errores de `onAuthStateChange`: un fallo de red al renovar el token no cierra la sesión. Solo se cierra si el servidor rechaza la sesión.
- Auth no tiene casos de uso: los ViewModels usan `AuthRepository` y las validaciones están en `core/utils/validators.dart` (incluida la lista local de contraseñas comunes de docs/08 §8.2.4).
- Después de guardar la contraseña con el código de recuperación se cierra la sesión en todos los dispositivos (`signOut(global)`) y el usuario vuelve a /login. Mientras la recuperación está en curso (`passwordRecoveryInProgressProvider`, se activa antes de verificar el código), el redirect no saca al usuario aunque haya sesión: `/recover` está apilada sobre `/login` y go_router evalúa el redirect con la ruta base (`/login`). La sesión temporal solo se cierra si el usuario sale por su cuenta (Volver o atrás del sistema, `RecoverPasswordViewModel.cancel`), nunca en un dispose.
- Con sesión, la app entra directo a /home hasta que exista el desbloqueo (Fase 6). La pantalla de verificación recibe el correo en `extra` de go_router y no lo muestra.
- Al registrarse, los metadatos del usuario llevan `nombre` y `politica_version` ("1"), para que la tabla perfiles los registre en 5B.

## Stack

- **Flutter (Dart)** para Android e iOS desde un solo código. Se desarrolla en Windows; iOS se compila después en un Mac.
- **Riverpod**: manejo de estado e inyección de dependencias.
- **go_router**: navegación.
- **intl**: formato de moneda y fechas.
- **Drift (SQLite) + SQLite3MultipleCiphers**: base de datos local cifrada (Fase 4).
- **uuid**, **path_provider** y **flutter_secure_storage**: ya incorporadas en la Fase 4 (identificadores, ubicación de la base y clave de cifrado).
- **Supabase** (`supabase_flutter`, incorporado en la Fase 5A): Auth, PostgreSQL con Row Level Security y Storage (Fase 5).
- **Paquetes del dispositivo** (Fase 6): `camera`, `image_picker`, `google_mlkit_text_recognition`, `flutter_local_notifications`, `local_auth`, `connectivity_plus`.

No agregues dependencias de una fase futura ni paquetes fuera de esta lista sin consultarme.

Identificador de la app: co.mislukas.app

## Arquitectura

Clean Architecture + MVVM, organizada por funcionalidad (feature-first).

- **Presentación**: Views (widgets) sin lógica + ViewModels (Notifiers de Riverpod) que exponen estados: cargando, con datos, vacío, error.
- **Dominio**: entidades, casos de uso e interfaces de repositorios. Dart puro, sin dependencias de Flutter, Drift ni Supabase.
- **Datos**: implementación de repositorios, fuente local (Drift), fuente remota (Supabase) y servicio de sincronización.

Las dependencias apuntan hacia adentro: presentación → dominio ← datos. La UI nunca habla directamente con la base de datos ni con Supabase.

Base local en `core/database/` (tablas, `AppDatabase`, apertura cifrada); repositorios y sus providers en `features/*/data/`; entidades, interfaces y casos de uso en `features/*/domain/` (providers de los casos de uso de reports y simulator en su `presentation/`).

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── config/      # Variables de entorno
│   ├── theme/       # AppColors, AppSpacing, AppRadius, AppTheme
│   ├── widgets/     # Componentes reutilizables
│   ├── router/      # Rutas de go_router
│   ├── utils/       # CurrencyFormatter, validaciones, fechas
│   ├── security/    # (Fase 5-6) almacenamiento seguro, biometría
│   ├── database/    # (Fase 4) Drift, tablas, migraciones
│   ├── sync/        # (Fase 5) sincronización
│   └── errors/      # Errores y mensajes para el usuario
└── features/
    ├── auth/        # Login, registro, recuperación, desbloqueo
    ├── home/        # Inicio: disponible, alertas, últimos movimientos
    ├── movements/   # Nuevo gasto, confirmación, OCR, historial
    ├── budgets/     # Categorías, presupuestos y alertas
    ├── reports/     # Reportes por categoría y comparación mensual
    ├── simulator/   # Simulador de ahorro
    └── profile/     # Perfil, seguridad, eliminación de cuenta
```

Cada feature tiene `data/`, `domain/` y `presentation/`. Crea `data/` y `domain/` solo cuando la fase lo requiera.

## Convenciones de código

- Nombres de clases, métodos y variables en **inglés**. Comentarios en **español**.
- Todo texto visible para el usuario en **español**.
- Usa siempre los tokens del tema (`AppColors`, `AppSpacing`, `AppRadius`, `Theme.of(context).textTheme`). **No escribas colores, tamaños ni espaciados a mano.**
- Antes de crear un widget, revisa si ya existe en `lib/core/widgets/`.
- Usa las APIs vigentes de Flutter; evita APIs deprecadas.
- Las pruebas van en `test/` con la misma estructura de `lib/`.
- Los colores de categoría usan el prefijo `category` (`AppColors.categoryMercado`, `AppColors.categoryIngreso`, etc.) para distinguirlos de los colores de estado (`success`, `error`).

## Componentes disponibles

En `lib/core/widgets/`. Importar siempre desde `package:mislukas/core/widgets/widgets.dart`.

- `AppPrimaryButton`: botón oscuro de ancho completo para la acción principal; estados cargando y deshabilitado.
- `AppSecondaryButton`: botón con borde de ancho completo, con badge opcional ("Próximamente") y variante `destructive` en rojo ("Eliminar movimiento").
- `AppBadge`: etiqueta pequeña ("Recomendado", "Próximamente") en tono primary, error o neutral.
- `AppTextField`: campo con etiqueta en mayúsculas, error, modo contraseña con ojo, `trailing` junto a la etiqueta, `maxLength`, `autofillHints` y `onSubmitted`.
- `AppFieldLabel`: etiqueta de campo en mayúsculas ("CATEGORÍA SUGERIDA").
- `AppAmountField`: campo grande de montos con "$", solo dígitos, puntos de miles y valor como `int`.
- `AppSummaryCard`: tarjeta principal azul con valor destacado y datos secundarios (disponible del mes, ahorro promedio).
- `AppIconButton`: botón cuadrado de 48 dp con solo ícono y tooltip (notificaciones, cerrar, volver).
- `AppCheckboxTile`: casilla con texto que puede incluir enlaces (`AppTextSegment`).
- `AppPasswordStrength`: barra de fortaleza (Débil/Media/Fuerte) y lista de requisitos de contraseña.
- `AppCodeField`: código de verificación de 6 dígitos en casillas, solo números, con autocompletado del código y error.
- `ReceiptPreview`: vista previa de un recibo con el total resaltado como "Área detectada".
- `AppCard`: tarjeta blanca con borde sutil y `onTap` opcional.
- `AppSectionHeader`: título de sección con acción opcional a la derecha ("Ver todos").
- `CategoryIcon`: ícono de categoría (`CategoryKind`) en un cuadrado con fondo pastel.
- `MovementTile`: fila de movimiento con ícono, "categoría · fecha", monto con signo e indicador de pendiente de sincronizar.
- `SelectableOptionCard`: tarjeta seleccionable con ícono, descripción, badge e indicador tipo radio.
- `AppChip` / `AppChipGroup`: chip seleccionable y grupo de selección única.
- `AppBanner`: franja con ícono, título y descripción en variantes warning, success, error e info.
- `AppSegmentedTabs`: selector de opciones con la activa en blanco ("Iniciar sesión | Registrarse").
- `AppEmptyState`: estado vacío con ícono, título, descripción y acción opcional.
- `AppOfflineIndicator`: aviso discreto de "Sin conexión".
- `AppSnackbar`: `AppSnackbar.success` / `AppSnackbar.error` / `AppSnackbar.info` para mensajes breves.
- `showAppConfirmDialog`: diálogo de confirmación con "Cancelar" y una acción (en rojo con `destructive`); devuelve true si el usuario confirma.
- `DemoDataActions` (`core/widgets/dev/`): "Cargar datos de demostración" y "Borrar todos los datos"; solo se muestra en modo desarrollo.
- `AppBottomNav`: barra inferior con Inicio, Reportes, Simular y Perfil.
- `AppDonutChart` / `AppChartSegment`: gráfico de dona (CustomPainter) con contenido central y descripción para lectores de pantalla.
- `AppBarComparisonChart` / `AppBarGroup`: barras verticales agrupadas de dos series (gris y primary) con leyenda; las etiquetas del eje no se enciman.
- `AppVariationBar`: barra horizontal proporcional (0 a 1) sobre pista gris, para variaciones.
- `AppLegendItem`: elemento de leyenda con punto o cuadro de color, etiqueta y valor opcional.
- `AppStatCard`: tarjeta de resultado con etiqueta en mayúsculas, valor, descripción y texto destacado; variante verde `highlighted`.
- `AppAvatar`: avatar circular con iniciales.

El estilo de cada categoría (etiqueta, color, fondo pastel, ícono) está en `CategoryKind` (`lib/core/theme/category_style.dart`). En modo debug, la galería `/dev/components` muestra todos los componentes.

## Reglas de negocio clave

- **Montos**: siempre `int` en pesos colombianos. Nunca `double`. Formato: `$1.874.320` (punto de miles, sin decimales) con `CurrencyFormatter`.
- **Disponible del mes** = ingresos del mes − gastos del mes.
- **Categorías predeterminadas**: Mercado, Transporte, Ocio, Servicios, Restaurantes, Otros (gastos) e Ingreso.
- **Alertas de presupuesto**: al 75% y al 100% del límite de una categoría. Cada alerta se envía **una sola vez por categoría, umbral y mes**.
- **Simulador**:
  - Ahorro promedio = promedio de (ingresos − gastos) de los últimos 3 meses completos.
  - Sin interés = P × n
  - Con interés = P × ((1 + r)^n − 1) / r, con r = 1.07^(1/12) − 1 (7% EA), n = años × 12.
  - Valores de referencia (P = 420.000, 3 años): sin interés $15.120.000; con interés $16.716.595; con +$50.000 al mes, $18.706.666.
  - Siempre mostrar el aviso: "Simulación estimada con tasa del 7% EA. No constituye asesoría financiera."
- **Validación de montos**: mayores que cero; rechazar vacíos, cero y negativos.

## Diseño (resumen)

Detalle completo en `docs/05-diseno-ui.md`.

- Fondo `#F8FAFC`, tarjetas blancas con borde sutil y sin sombra.
- Azul primario `#2563EB` para destacados y pestaña activa. Botón de acción principal casi negro `#111827`, ancho completo, en la parte inferior.
- Verde para ingresos y reducciones; rojo para gastos, errores y aumentos; amarillo para alertas. La información nunca depende solo del color: los montos llevan signo y las variaciones, porcentaje.
- Áreas táctiles mínimas de 48 dp.
- La barra de navegación inferior (Inicio · Reportes · Simular · Perfil) siempre fija abajo.
- Toda pantalla contempla sus estados: cargando, vacío, error, sin conexión, pendiente de sincronizar.
- Colores de categoría: Mercado #2563EB, Transporte #F59E0B, Ocio #8B5CF6, Servicios #0D9488, Restaurantes #DB2777, Otros #F87171, Ingreso #16A34A.

## Offline-first

- La UI lee y escribe **siempre** en la base local. Supabase es respaldo y sincronización.
- IDs **UUID generados en el dispositivo**.
- Todas las tablas llevan `creado_en`, `actualizado_en` y `eliminado_en` (borrado lógico).
- Registros locales con `estado_sync`: sincronizado, pendiente o error.
- Sincronización: primero enviar (push con upsert), luego recibir (pull por `sincronizado_en`). Conflictos: la última escritura gana; la eliminación prevalece.

## Seguridad (no negociable)

Detalle completo en `docs/08-seguridad.md`.

- **Nunca** incluir la clave `service_role` de Supabase en la app ni en el repositorio.
- **Nunca** escribir claves, URLs privadas ni secretos en el código; usar variables de entorno (`--dart-define`).
- Tokens de sesión, clave de cifrado y hash del PIN: **solo** en `flutter_secure_storage`.
- **Nunca** guardar datos financieros en SharedPreferences ni en almacenamiento sin cifrar.
- **Nunca** escribir en logs tokens, montos, correos ni contenido de recibos.
- Consultas siempre parametrizadas. No construir SQL con interpolación de texto.
- Toda validación del cliente debe tener su equivalente en el servidor.
- Errores de login y recuperación con mensajes genéricos (no revelar si un correo existe).
- Todas las tablas de Supabase con Row Level Security activado.

## Fases del desarrollo

1. **Base del proyecto**: estructura, tema visual, tipografía DM Sans, formato de moneda.
2. **Componentes y navegación**: widgets reutilizables, go_router, barra inferior.
3. **Pantallas con datos de prueba**: las 6 pantallas de los bocetos con datos ficticios.
4. **Dominio y base local**: entidades, casos de uso, Drift + SQLite3MultipleCiphers.
5. **Supabase**: autenticación, RLS, sincronización.
6. **Funciones del dispositivo**: cámara, OCR, notificaciones, biometría.

**Fase actual: 5**

## Comandos

```
flutter pub get        # Instalar dependencias
flutter analyze        # Análisis estático (debe quedar sin errores ni warnings)
flutter test           # Pruebas
flutter run --dart-define-from-file=env/dev.json   # Ejecutar en el emulador
```

`env/dev.json` (ignorado por git) tiene `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`; se crea copiando `env/dev.example.json`. Sin esas variables la app falla al iniciar con un mensaje. `.vscode/launch.json` ya pasa ese argumento.

El entorno es Windows con terminal cmd.

## Forma de trabajo

- Antes de terminar cualquier tarea: `flutter analyze` sin errores ni warnings y `flutter test` pasando.
- No modifiques `android/` ni `ios/` salvo que la fase lo requiera, y avísame cuando lo hagas.
- **No hagas commit ni push.** Yo reviso y hago el commit.
- Si algo es ambiguo o contradice la documentación, pregunta antes de decidir.
- Al terminar, entrega un resumen breve: archivos creados o modificados, resultado de analyze y test, y decisiones tomadas.
