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
- Esquema remoto en `supabase/migrations/` (001 a 008 de la 5B, 009 de la 5C), ejecutado a mano en el SQL Editor. Cada archivo es una transacción (`begin/commit`) y es repetible. `supabase/verify.sql` comprueba RLS, permisos y aislamiento entre dos usuarios. `supabase/rollback_5b.sql` deshace todo (solo en desarrollo).
- Las categorías predeterminadas son filas globales en Supabase, con `usuario_id` null y los mismos UUID fijos (docs/06 y docs/08). Es la única columna `usuario_id` nullable. Todos las leen, nadie las modifica y la app no las envía.
- En Supabase, `usuario_id` tiene `default auth.uid()` y `sincronizado_en` la asigna un trigger. El cliente no envía ninguno de los dos.
- Presupuestos y recibos son únicos solo entre los no eliminados, con índices únicos parciales (`where eliminado_en is null`), tanto en Supabase como en Drift. En Supabase los índices incluyen `usuario_id`: (usuario_id, categoria_id, mes) en presupuestos y (usuario_id, movimiento_id) en recibos (migración 008). Si el índice de recibos fuera solo sobre `movimiento_id`, el recibo de otro usuario chocaría con él (23505) antes de que actuara la llave foránea (23503), y el código de error revelaría que ese movimiento existe. En Drift los índices no llevan `usuario_id`, porque la base local es de un solo usuario. El único `unique` total extra es `movimientos (usuario_id, id)`, destino de la llave foránea compuesta de recibos: un recibo solo puede apuntar a un movimiento del mismo usuario. Un trigger (`validar_categoria_del_usuario`) exige que la categoría sea predeterminada o del mismo usuario.
- `perfiles` se crea con un trigger SECURITY DEFINER en `auth.users`, que rechaza el registro si falta `politica_version`. Guarda `politica_aceptada_en`. El usuario solo puede actualizar `nombre` (grant por columna).
- El check del tipo de movimiento se llama `movimientos_tipo_check`, para ampliarlo con una migración (por ejemplo, 'saldo_inicial').
- Bucket privado `recibos`: 5 MB, JPEG y PNG, ruta `{usuario_id}/{recibo_id}.jpg` sin subcarpetas. Hay políticas de select, insert y update; ninguna de delete. `recibos.ruta_storage` debe empezar por la carpeta del dueño.
- Base local en la versión 3 de Drift. En la v2, `recibos.ruta_local` admite null (un recibo que llega del servidor no trae la imagen) y `Receipt.localPath` es `String?`. En la v3, `cola_sincronizacion` tiene `proximo_intento` y `ultimo_error` (solo el código).
- DTOs remotos (5B) en `features/*/data/remote/`. Convierten entre filas de Drift y JSON de Supabase con `RemoteJson` (`core/sync/remote_json.dart`). `toCompanion()` deja `estado_sync = 'sincronizado'`, y el de recibos no toca `ruta_local`.
- Sincronización (5C) en `core/sync/`:
  - `SyncService` hace push, luego pull, y otro push si el pull dejó algo en la cola. Solo corre una ejecución a la vez.
  - `SyncRemoteSource` es la fuente remota: `SupabaseSyncRemoteSource` en la app y `FakeSyncServer` en las pruebas.
  - `LocalSyncStore` maneja la cola, la aplicación de filas remotas y los cursores. `sync_tables.dart` describe las 4 tablas en el orden de sus llaves foráneas.
- Push:
  - Varias entradas de un mismo registro se envían como un solo upsert con la fila actual. Los lotes son de 100 y van agrupados por las mismas columnas. Dentro de cada tabla, las eliminaciones van primero.
  - Si un lote es rechazado, se reenvía de a un registro. El registro rechazado queda con `estado_sync = error` y espera 5 min · 2^(n−1), con tope de 24 h. Los errores de red o de sesión detienen el push sin marcar nada.
  - El primer 23505 en una tabla con "único entre activos" se difiere: lo resuelve el pull.
- Pull:
  - Avanza por llave (sincronizado_en, id) desde el cursor menos 5 min de solape, en páginas de 200. Ignora las categorías predeterminadas.
  - Un eliminado que llega del servidor se guarda como lápida. Si la fila es igual a la local, no se escribe nada.
  - Si dos presupuestos activos de la misma categoría y mes tienen ids distintos, gana el de `actualizado_en` mayor (con empate, el de id mayor) y el otro se elimina de forma lógica.
- En el servidor, la migración 009 aplica la misma regla con un trigger (`conservar_ultima_escritura`): una versión más vieja no reemplaza a la guardada, una eliminación siempre se acepta y un registro eliminado ya no cambia. `DriftBudgetRepository.save` ya no revive presupuestos eliminados: crea uno con id nuevo.
- `SyncController` (`core/sync/sync_controller.dart`) solo sincroniza con la sesión lista:
  - al abrir la app o iniciar sesión;
  - 2 s después de cada escritura (observa la cola);
  - al volver a primer plano (`SyncTriggers` en `app.dart`);
  - cada 5 min;
  - sin conexión, con reintentos a 5, 10, 20, 40 y 60 s.

  Sin connectivity_plus (Fase 6), "sin conexión" es el resultado del último intento. `syncAutoTriggersProvider` lo apaga en las pruebas.
- La base local tiene dueño: el id del usuario se guarda en `flutter_secure_storage` (`DeviceSessionStore`). `AccountSessionController` (`features/auth/presentation/`) da el estado `signedOut`, `foreignData`, `wiping` o `ready`. El router solo cuenta la sesión con `ready`.
  - Si entra otro usuario, `ForeignDataPrompt` pide confirmar y se borra todo antes de abrir la base. Hay uno solo, global: está montado en el `builder` de `MaterialApp.router` y abre su diálogo en el navegador raíz (`rootNavigatorKeyProvider`). Así aparece una sola vez después del login, de verificar el registro o en cualquier pantalla. Si no puede mostrarse, cierra la sesión con un mensaje (`accountNoticeProvider`).
  - El borrado (`FileLocalDataWiper`) borra primero la clave y el dueño. Después cierra la base (con tope de 5 s) y borra los archivos; los errores de esos dos pasos se ignoran. Al abrir, una base sin clave guardada se descarta (`deleteStaleDatabase`).
  - El controlador tiene un tope de 15 s por borrado y siempre recalcula el estado al terminar. Un cierre de sesión se aplica de inmediato aunque haya un borrado en curso. Nunca queda con sesión sin `ready` ni aviso.
  - Después de un cierre voluntario el dueño se borra en memoria y en el almacenamiento seguro; la siguiente cuenta entra sin aviso. Solo si no se pudo borrar la clave se conserva el dueño, y entonces la siguiente cuenta ve el aviso.
  - Una base sin dueño (de antes de 5C) pasa al usuario que entra.
- Una sesión revocada sin que el usuario la cierre conserva los datos cifrados (docs/06 §6.6.4, docs/08 §8.2.6).
- `AccountActions` cierra la sesión: intenta enviar todo (10 s). Si quedan pendientes, el Perfil pide confirmar que se pierden. Luego cierra la sesión y `LocalDataWiper` borra la base (con `-wal`, `-shm` y `-journal`), la carpeta `recibos/`, la clave de cifrado y el dueño. `appDatabaseProvider` se invalida y la próxima base usa una clave nueva.
- La marca de recuperación en curso también se guarda en el almacenamiento seguro. Si la app se cerró después de verificar el código, `main()` cierra esa sesión temporal antes de abrir la base (`clearInterruptedRecovery`).
- Eliminación de cuenta (5C), sin Edge Function ni service_role:
  - La app verifica de nuevo la contraseña (`AuthRepository.reauthenticate`).
  - Borra `{uid}/*` en Storage en páginas de 100 (política de delete de la 009).
  - Llama a `eliminar_mi_cuenta()`, que es SECURITY DEFINER, borra solo `auth.uid()` en cascada y exige el claim `amr` con la contraseña verificada hace menos de 5 min y que no queden archivos. Responde `P0001` con hint `reautenticacion` o `archivos_pendientes`.
  - Si la RPC falla después de borrar los archivos, se reintenta sin pedir la contraseña durante 4 min 30 s.
  - Pantalla `/profile/delete-account`, construida con `AuthFlowScaffold`.
  - Queda pendiente el correo que confirma la eliminación (requiere SMTP).
- Inicio: `MovementTile.isPendingSync` se muestra en lo pendiente o rechazado, y deslizar hacia abajo sincroniza. MainShell muestra `AppOfflineIndicator`. El Perfil muestra el estado de la sincronización con `AppBanner` (`SyncStatusBanner`).

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
