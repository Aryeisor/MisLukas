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

## Stack

- **Flutter (Dart)** para Android e iOS desde un solo código. Se desarrolla en Windows; iOS se compila después en un Mac.
- **Riverpod**: manejo de estado e inyección de dependencias.
- **go_router**: navegación.
- **intl**: formato de moneda y fechas.
- **Drift (SQLite) + SQLCipher**: base de datos local cifrada (Fase 4).
- **Supabase**: Auth, PostgreSQL con Row Level Security y Storage (Fase 5).
- **Paquetes del dispositivo** (Fase 6): `camera`, `image_picker`, `google_mlkit_text_recognition`, `flutter_local_notifications`, `flutter_secure_storage`, `local_auth`, `connectivity_plus`.

No agregues dependencias de una fase futura ni paquetes fuera de esta lista sin consultarme.

## Arquitectura

Clean Architecture + MVVM, organizada por funcionalidad (feature-first).

- **Presentación**: Views (widgets) sin lógica + ViewModels (Notifiers de Riverpod) que exponen estados: cargando, con datos, vacío, error.
- **Dominio**: entidades, casos de uso e interfaces de repositorios. Dart puro, sin dependencias de Flutter, Drift ni Supabase.
- **Datos**: implementación de repositorios, fuente local (Drift), fuente remota (Supabase) y servicio de sincronización.

Las dependencias apuntan hacia adentro: presentación → dominio ← datos. La UI nunca habla directamente con la base de datos ni con Supabase.

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
4. **Dominio y base local**: entidades, casos de uso, Drift + SQLCipher.
5. **Supabase**: autenticación, RLS, sincronización.
6. **Funciones del dispositivo**: cámara, OCR, notificaciones, biometría.

**Fase actual: 2**

## Comandos

```
flutter pub get        # Instalar dependencias
flutter analyze        # Análisis estático (debe quedar sin errores ni warnings)
flutter test           # Pruebas
flutter run            # Ejecutar en el emulador
```

El entorno es Windows con terminal cmd.

## Forma de trabajo

- Antes de terminar cualquier tarea: `flutter analyze` sin errores ni warnings y `flutter test` pasando.
- No modifiques `android/` ni `ios/` salvo que la fase lo requiera, y avísame cuando lo hagas.
- **No hagas commit ni push.** Yo reviso y hago el commit.
- Si algo es ambiguo o contradice la documentación, pregunta antes de decidir.
- Al terminar, entrega un resumen breve: archivos creados o modificados, resultado de analyze y test, y decisiones tomadas.
