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
| `docs/09-pruebas.md` | Evidencias: verify.sql, pruebas automáticas, pruebas manuales, mediciones y capturas pendientes |

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
- Con sesión, la app entra a /home; si el bloqueo está activo, `AppLockGate` la cubre hasta desbloquear (6C). La pantalla de verificación recibe el correo en `extra` de go_router y no lo muestra.
- Al registrarse, los metadatos del usuario llevan `nombre` y `politica_version` ("1"), para que la tabla perfiles los registre en 5B.
- Esquema remoto en `supabase/migrations/` (001 a 008 de la 5B, 009 de la 5C), ejecutado a mano en el SQL Editor. Cada archivo es una transacción (`begin/commit`) y es repetible. `supabase/verify.sql` comprueba RLS, permisos y aislamiento entre dos usuarios. `supabase/rollback_5b.sql` deshace todo (solo en desarrollo).
- Las categorías predeterminadas son filas globales en Supabase, con `usuario_id` null y los mismos UUID fijos (docs/06 y docs/08). Es la única columna `usuario_id` nullable. Todos las leen, nadie las modifica y la app no las envía.
- En Supabase, `usuario_id` tiene `default auth.uid()` y `sincronizado_en` la asigna un trigger. El cliente no envía ninguno de los dos.
- Presupuestos y recibos son únicos solo entre los no eliminados, con índices únicos parciales (`where eliminado_en is null`), tanto en Supabase como en Drift. En Supabase los índices incluyen `usuario_id`: (usuario_id, categoria_id, mes) en presupuestos y (usuario_id, movimiento_id) en recibos (migración 008). Si el índice de recibos fuera solo sobre `movimiento_id`, el recibo de otro usuario chocaría con él (23505) antes de que actuara la llave foránea (23503), y el código de error revelaría que ese movimiento existe. En Drift los índices no llevan `usuario_id`, porque la base local es de un solo usuario. El único `unique` total extra es `movimientos (usuario_id, id)`, destino de la llave foránea compuesta de recibos: un recibo solo puede apuntar a un movimiento del mismo usuario. Un trigger (`validar_categoria_del_usuario`) exige que la categoría sea predeterminada o del mismo usuario.
- `perfiles` se crea con un trigger SECURITY DEFINER en `auth.users`, que rechaza el registro si falta `politica_version`. Guarda `politica_aceptada_en`. El usuario solo puede actualizar `nombre` (grant por columna).
- El check del tipo de movimiento se llama `movimientos_tipo_check`, para ampliarlo con una migración (por ejemplo, 'saldo_inicial').
- Bucket privado `recibos`: 5 MB, JPEG y PNG, ruta `{usuario_id}/{recibo_id}.jpg` sin subcarpetas. Hay políticas de select, insert y update; ninguna de delete. `recibos.ruta_storage` debe empezar por la carpeta del dueño.
- Base local en la versión 5 de Drift. En la v2, `recibos.ruta_local` admite null (un recibo que llega del servidor no trae la imagen) y `Receipt.localPath` es `String?`. En la v3, `cola_sincronizacion` tiene `proximo_intento` y `ultimo_error` (solo el código). En la v4 se agrega `ajustes_locales` (clave, valor): ajustes del dispositivo, sin sincronizar, que se borran con la base. En la v5 (6B) se agrega `alertas_enviadas` (categoria_id, mes, umbral 75/100, enviada_en; PK de las tres primeras), tampoco sincronizada.
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
  - sin conexión, con reintentos a 5, 10, 20, 40 y 60 s;
  - al recuperar la red (connectivity_plus, 6B), 2 s después del último cambio.

  "Sin conexión" combina las dos señales (ver Señal de conexión, 6B). `syncAutoTriggersProvider` lo apaga en las pruebas.
- La base local tiene dueño: el id del usuario se guarda en `flutter_secure_storage` (`DeviceSessionStore`). `AccountSessionController` (`features/auth/presentation/`) da el estado `signedOut`, `foreignData`, `wiping` o `ready`. El router solo cuenta la sesión con `ready`.
  - Si entra otro usuario, `ForeignDataPrompt` pide confirmar y se borra todo antes de abrir la base. Hay uno solo, global: está montado en el `builder` de `MaterialApp.router` y abre su diálogo en el navegador raíz (`rootNavigatorKeyProvider`). Así aparece una sola vez después del login, de verificar el registro o en cualquier pantalla. Si no puede mostrarse, cierra la sesión con un mensaje (`accountNoticeProvider`).
  - El borrado (`FileLocalDataWiper`) borra primero la clave y el dueño. Después cierra la base (con tope de 5 s) y borra los archivos; los errores de esos dos pasos se ignoran. Al abrir, una base sin clave guardada se descarta (`deleteStaleDatabase`).
  - El controlador tiene un tope de 15 s por borrado y siempre recalcula el estado al terminar. Un cierre de sesión se aplica de inmediato aunque haya un borrado en curso. Nunca queda con sesión sin `ready` ni aviso.
  - Después de un cierre voluntario el dueño se borra en memoria y en el almacenamiento seguro; la siguiente cuenta entra sin aviso. Solo si no se pudo borrar la clave se conserva el dueño, y entonces la siguiente cuenta ve el aviso.
  - Una base sin dueño (de antes de 5C) pasa al usuario que entra.
- Una sesión revocada sin que el usuario la cierre conserva los datos cifrados (docs/06 §6.6.4, docs/08 §8.2.6).
- `AccountActions.signOut` es el borrado total (con "Ingresar con huella, rostro o PIN" activo, "Cerrar sesión" normal es `park`, ver 6C): intenta enviar todo (10 s). Si quedan pendientes, el Perfil pide confirmar que se pierden. Luego cierra la sesión y `LocalDataWiper` borra la base (con `-wal`, `-shm` y `-journal`), la carpeta `recibos/`, las claves de cifrado, el dueño, la sesión en espera y la preferencia de ingreso con el bloqueo del celular. `appDatabaseProvider` se invalida y la próxima base usa una clave nueva.
- La marca de recuperación en curso también se guarda en el almacenamiento seguro. Si la app se cerró después de verificar el código, `main()` cierra esa sesión temporal antes de abrir la base (`clearInterruptedRecovery`).
- Eliminación de cuenta (5C), sin Edge Function ni service_role:
  - La app verifica de nuevo la contraseña (`AuthRepository.reauthenticate`).
  - Borra `{uid}/*` en Storage en páginas de 100 (política de delete de la 009).
  - Llama a `eliminar_mi_cuenta()`, que es SECURITY DEFINER, borra solo `auth.uid()` en cascada y exige el claim `amr` con la contraseña verificada hace menos de 5 min y que no queden archivos. Responde `P0001` con hint `reautenticacion` o `archivos_pendientes`.
  - Si la RPC falla después de borrar los archivos, se reintenta sin pedir la contraseña durante 4 min 30 s.
  - Pantalla `/profile/delete-account`, construida con `AuthFlowScaffold`.
  - Queda pendiente el correo que confirma la eliminación (requiere SMTP).
- Inicio: `MovementTile.isPendingSync` se muestra en lo pendiente o rechazado, y deslizar hacia abajo sincroniza. MainShell muestra `AppOfflineIndicator`. El Perfil muestra el estado de la sincronización con `AppBanner` (`SyncStatusBanner`).
- Ingresos (5D, RF-50):
  - El botón de Inicio dice "Nuevo movimiento" (el boceto 5.4 dice "Nuevo gasto") y abre `/movements/new`, que tiene el selector Gasto | Ingreso (`AppSegmentedTabs` dentro de `Semantics(label: 'Tipo de movimiento')`). Gasto viene seleccionado; `?type=income` abre Ingreso.
  - El ingreso se registra en la misma pantalla con `IncomeFormFields` (`movements/presentation/widgets/`): valor, descripción y fecha. Usa `RegisterIncome`, que delega en `RegisterMovement` con la categoría Ingreso, origen manual y sin recibo. Las validaciones son las mismas: monto, largo y fecha no futura.
  - En `ConfirmMovementViewModel` el modo es `CreateIncomeMode`. Al editar un ingreso se muestra el mismo formulario (sin categorías ni nota) y se guarda con `UpdateMovement(amount, description, date)`.
  - La fecha es un `AppSecondaryButton` ("Hoy, 17 de octubre", `DateLabels.longDay`) que abre `showDatePicker` con `lastDate` = hoy. El formulario de gasto sigue sin fecha (usa hoy).
  - `flutter_localizations` (SDK) con `es_CO` en `MaterialApp.router` (`core/config/app_localization.dart`), para que el calendario salga en español.
- Bienvenida (5D, RF-51, `features/onboarding/`):
  - "Usuario nuevo" significa que no tiene ningún dato propio: movimientos, presupuestos (aunque estén eliminados) ni categorías propias. Lo revisa `OnboardingRepository.hasOwnData`.
  - Se decide después de la primera sincronización exitosa de la sesión. `WelcomeController` escucha cuándo cambia `SyncState.lastSyncedAt`; sin conexión espera.
  - Si el usuario tiene datos, la marca queda como completada sin mostrar nada. La marca vive en `ajustes_locales` (`bienvenida = completada`) y se va con la base al cerrar sesión o al entrar otro usuario.
  - `WelcomeLauncher` (en el `builder` de `MaterialApp.router`) abre `/welcome` con `push`, no con el redirect, para no perder un formulario abierto. Durante la recuperación de contraseña la sesión no está `ready`, así que no se decide nada.
  - Paso 1: ingresos con `RegisterIncome`. Al volver y continuar, los ya guardados se actualizan y los quitados se eliminan (no se duplican). Paso 2: presupuestos opcionales con `SetBudget`.
  - Omitir el paso 1 pasa al 2. Terminar u omitir el paso 2, o Volver en el paso 1, la marca como completada.
  - `DemoSeed.load()` también marca la bienvenida; `clearAll()` no la toca.
  - Limitación conocida: la marca es local. Quien la omitió sin registrar nada la ve de nuevo en otro celular. No hay columnas en Supabase para esto.
- Historial (5E, RF-22, `movements/presentation/history/`):
  - Ruta `/movements/history`, desde "Ver todos" de Inicio. Agrupado por mes, del más reciente al más antiguo, con `MovementTile` y el total de ingresos y gastos de cada mes.
  - Filtro `AppSegmentedTabs` Todos | Gastos | Ingresos y `AppChipGroup<CategoryKind?>` con "Todas" y las categorías de gasto (ocultos con Ingresos). RF-22 pide "por mes y categoría": el mes lo da la agrupación.
  - Carga por ventana de meses: `MovementRepository.watchMonthSummaries` agrupa en SQL (`substr(fecha, 1, 7)`) para saber qué meses hay, y solo se leen los movimientos de los 3 más recientes; al llegar al final se suman 3 (`WatchMovementHistory`, `switchMap` en `core/utils/streams.dart`). Los totales del encabezado se calculan con los movimientos cargados. `watchBetween` acepta un `MovementFilter` (tipo y categoría).
- Presupuestos (5E, RF-52):
  - Pantalla `/profile/budgets` (`BudgetsScreen`), desde Perfil › Preferencias › "Presupuestos" (docs/05 pantalla 10).
  - Una tarjeta por categoría de gasto con gastado, límite, `AppVariationBar` (azul, amarilla desde 75%, roja desde 100%) y el porcentaje escrito. Al tocarla se edita en la misma tarjeta (una a la vez): Guardar (`SetBudget`), Cancelar y Quitar (`RemoveBudget`, con confirmación).
  - `BudgetCategoryHeader` y `BudgetLimitField` (`budgets/presentation/widgets/`) los comparten la bienvenida (paso 2) y Presupuestos.
  - `BudgetRepository` tiene `findById`, `remove` (borrado lógico con entrada `eliminar` en la cola) y `carryOver`. `DomainError.budgetNotFound`.
- Continuidad entre meses (5E, RF-53):
  - `BudgetRepository.carryOver`, en una transacción: si el mes actual tiene alguna fila de presupuesto (activa o eliminada) no hace nada; si no, toma el último mes anterior con alguna fila (también eliminadas) y copia sus activos con ids nuevos, mismos límites, pendientes y con su entrada `crear` en la cola. Así es idempotente, un presupuesto quitado en el mes no vuelve y, si el usuario los quitó todos, el mes siguiente queda vacío.
  - `BudgetCarryOverController` corre `CarryOverBudgets` cada vez que termina un intento de sincronización (`isSyncing` pasa a false), salga bien o no, con la sesión `ready`. Con conexión el pull ya trajo lo que copió otro celular. Se mantiene vivo en `SyncTriggers` (`app.dart`).
  - Si dos celulares copian el mismo mes sin conexión, la resolución de "único entre activos" de la 5C deja uno por categoría; las copias perdedoras quedan como lápidas y no se vuelve a copiar.
  - Las alertas no cambian: se evalúan con los presupuestos y gastos de cada mes, así que el mes nuevo empieza sin alertas.
- Fecha del gasto (5E, RF-19): `MovementDateField` (`movements/presentation/widgets/`) es el selector de fecha del ingreso y del gasto (AppFieldLabel + AppSecondaryButton + `showDatePicker` con `lastDate` = hoy). El gasto (foto, manual y edición) empieza con hoy (`ConfirmMovementState.date`) y se guarda con `RegisterMovement`/`UpdateMovement(date)`. Disponible, Reportes, alertas y simulador ya filtran por `fecha`. En Supabase no hay check de fecha futura (tampoco para el ingreso de la 5D): la validación es solo del cliente.
- Foto del recibo (6A, RF-14 a RF-18):
  - Visor propio con `camera` (docs/07 §7.1) en `/movements/new/receipt` (`ReceiptCaptureScreen`, `movements/presentation/receipt/`). Galería con `image_picker`, sin "Usar foto" / "Repetir". "Continuar" con foto abre la captura; al terminar, `pushReplacement` a `/movements/confirm` con `ReceiptCapture` en `extra`. Sin `extra`, `?method=photo` redirige a la captura y sin `method` es el registro manual.
  - Calidad en `receipt_capture_settings.dart`: cámara `ResolutionPreset.veryHigh` (1080p), JPEG, `enableAudio: false`; galería 1920 px, calidad 85, `requestFullMetadata: false`. Sin paquete de compresión. Más de 5 MB → "La imagen es muy grande".
  - Permiso con `permission_handler` (`CameraPermissionService`): explicación previa, negado, negado permanente (Ajustes; se revisa de nuevo al volver a primer plano) y bloqueado. Siempre se ofrece galería o registro manual.
  - OCR con `google_mlkit_text_recognition` (latino, modelo incluido) detrás de `ReceiptTextReader`. `ReceiptParser` (`movements/domain/receipt/`, Dart puro) agrupa las líneas en filas por su ubicación y extrae total (palabras clave con prioridad y exclusiones; con empate, la fila más abajo), comercio (diccionario `merchant_dictionary.dart` o primera fila válida), fecha (día antes que mes; futura, inválida o anterior a 2000 → hoy) y categoría (RF-16).
  - Sin palabra clave de total, el valor queda vacío: no se propone el número más alto (se quitó de docs/07).
  - `ScanReceipt` nunca falla: un error del OCR es `ReceiptScanStatus.empty`. Estados: `complete` (hay total, banner verde), `partial` (texto sin total, amarillo) y `empty` (rojo).
  - `ConfirmMovementMode`: `CreateManualMovementMode` y `CreatePhotoMovementMode(ReceiptCapture)` (reemplazan a `CreateMovementMode(method)`). En la variante foto hay un campo COMERCIO (no está en el boceto 5.6) que se guarda como descripción. `ReceiptDraft` lleva el `id` del recibo (el de su archivo); `total_detectado` y `comercio_detectado` guardan lo leído, aunque el usuario lo corrija.
- Imágenes de recibos cifradas (6A, docs/07 §7.5):
  - AES-256-GCM con `cryptography` + `cryptography_flutter` (nativo: javax.crypto / CryptoKit; se registra solo, sin `enable()`). Clave propia de 32 bytes en `ReceiptKeyStore` (`core/security/`, `mislukas.receipt_key`), distinta de la de la base; creación idempotente y serializada. El wiper la borra junto con la de la base.
  - `FileReceiptImageStore`: `recibos/tmp/<id>.<ext>` sin cifrar solo mientras corre el OCR; `recibos/<id>.enc` = nonce (12) ‖ cifrado ‖ MAC (16), con el id del recibo como dato asociado y escritura atómica. `ruta_local` es relativa (`recibos/<id>.enc`). El temporal se borra en un `finally`, al repetir, al salir y si algo falla. Solo cifra o borra archivos dentro de `recibos/tmp/`.
  - La vista previa descifra en memoria (`receiptImageProvider`, nunca lanza) y usa `Image.memory`. `ReceiptImage`: `available`, `notOnDevice` ("La foto solo está en el celular donde se tomó") o `unreadable` ("No pudimos mostrar la foto del recibo").
  - `receiptDraftsInProgressProvider` registra el recibo desde la foto hasta que se guarda o se descarta. `ReceiptCleanupController` (en `SyncTriggers`) corre `CleanReceiptImages` una sola vez por arranque, cuando la sesión queda `ready`, sin tocar los recibos en curso; también limpia lo que la cámara (`CAP*.jpg`) y image_picker (`scaled_*`, `<uuid>/`) dejan en la caché. Salir de Confirma los datos sin guardar borra el `.enc`; eliminar un movimiento borra su imagen.
  - "Medir cifrado de recibos" (`ReceiptCipherBenchmarkAction`, `core/widgets/dev/`) se muestra en el Perfil con `!kReleaseMode` (también en `--profile`); el criterio es ≤ 300 ms entre cifrar y descifrar 1 MB.
  - Medición en el Galaxy J4 (armeabi-v7a, `--profile`, mediana de 10 corridas con 1 MB): cifrar 48 ms, descifrar 54 ms, total 102 ms. El OCR no mostró retardo perceptible, así que se mantiene 1080p. Evidencias de pruebas en `docs/09-pruebas.md`.
  - `ReceiptParser` evalúa palabras clave, exclusiones y fechas por línea de ML Kit (`ReceiptRow.lines`, `ReceiptLine`), no por fila visual: el texto de otro papel a la misma altura no descarta la fila ni aporta su monto. El visor dice "Ubica el recibo dentro del marco, sobre una superficie lisa y sin otros papeles" (`ReceiptFrameHint`).
  - Respaldo en Storage pendiente: `ruta_storage` sigue en null, la foto solo vive en el celular donde se tomó. Eliminar solo la foto (docs/08 §8.9.3) también queda pendiente.
- Android (6A): el manifiesto declara `CAMERA`, la cámara como no obligatoria (`camera.any` con `tools:replace`) y quita `RECORD_AUDIO` y `WRITE_EXTERNAL_STORAGE`, que agrega `camera_android_camerax`, y `READ_EXTERNAL_STORAGE`, que el combinador agrega como implícito. `android/app/proguard-rules.pro` tiene los `-dontwarn` de los reconocedores de ML Kit de otros alfabetos, sin los que R8 falla. iOS: `NSCameraUsageDescription` y `NSPhotoLibraryUsageDescription` en `Info.plist`; quedan para el Mac la macro `PERMISSION_CAMERA=1` en el Podfile y el mínimo de iOS 15.5 de ML Kit.
- Android (6B):
  - `build.gradle.kts` activa core library desugaring (`desugar_jdk_libs` 2.1.4), que exige flutter_local_notifications. El minSdk de Flutter ya es 24.
  - El manifiesto `main` declara `INTERNET` (antes solo estaba en `debug/` y `profile/`), `ACCESS_NETWORK_STATE` y `POST_NOTIFICATIONS`.
  - `res/drawable/ic_stat_alerta.xml` es el ícono de la notificación, y `res/raw/keep.xml` lo protege de la reducción de recursos.
  - El manifiesto combinado de release no tiene `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `USE_FULL_SCREEN_INTENT` ni `FOREGROUND_SERVICE`. Si un plugin los agregara, se quitan con `tools:node="remove"`.
  - iOS: queda para el Mac la macro `PERMISSION_NOTIFICATIONS=1`.
- Alertas de presupuesto (6B, RF-32, docs/07 §7.4):
  - `NotifyBudgetAlerts` (`budgets/domain/usecases/`) evalúa el mes actual y usa `pendingBudgetAlerts` (`budget_alert_notice.dart`). Registra todos los umbrales cruzados que faltan (`BudgetAlertLog`, tabla `alertas_enviadas`) y notifica solo el más alto. Registra antes de notificar.
  - Nada se quita del registro: si el gasto baja o el límite sube, el umbral no se repite en el mes.
  - Línea base: la primera evaluación de una base (`alertas_linea_base` en `ajustes_locales`) registra lo ya cruzado sin notificar. `BudgetAlertNotificationController` no evalúa hasta la primera sincronización exitosa de la sesión (`SyncState.lastSyncedAt != null`), salvo que ya exista la línea base.
  - El controlador, en `SyncTriggers`, se suscribe a `WatchBudgetAlerts` del mes: cubre registrar, editar o eliminar un gasto, crear, cambiar o quitar un presupuesto y el pull. También evalúa al terminar cada sincronización.
    - Observa `clockProvider`, así que "Adelantar un mes" evalúa el mes nuevo. Si el mes cambia con la app abierta, se reinicia en la siguiente sincronización.
    - Corre una evaluación a la vez y repite si llegó otro cambio. No usa temporizador: un `Timer` pendiente rompería las pruebas de widgets.
  - Texto (`BudgetAlertNotice.body`), sin montos:
    - "Llevas el 78% de tu presupuesto de Mercado."
    - "Llegaste al 100% de tu presupuesto de Mercado de octubre." (exactamente 100)
    - "Superaste tu presupuesto de Mercado de octubre." (más de 100)
    - Título "Alerta de presupuesto".
  - `LocalNotifications` (`core/notifications/`): se inicializa en `main()` y se pasa por override.
    - Canal `alertas_presupuesto`, `NotificationVisibility.private`.
    - Id estable FNV-1a de categoría y mes (`budgetAlertNotificationId`), así la del 100% reemplaza a la del 75%.
    - Payload: solo `/profile/budgets`.
    - No se programan notificaciones.
  - `NotificationTapLauncher` (en el `builder`, junto a `WelcomeLauncher`) hace push a Presupuestos con la sesión `ready` y la app desbloqueada (6C). Solo acepta esa ruta.
  - Permiso (`NotificationPermissionService`, `Permission.notification` de permission_handler 12.0.3):
    - `maybeAskNotificationPermission` (`budgets/presentation/notification_permission_flow.dart`) se llama después de guardar un presupuesto (Presupuestos y paso 2 de la bienvenida).
    - Explicación previa "Te avisamos de tus presupuestos" con "Permitir" / "Ahora no" (`showAppConfirmDialog` con `cancelLabel`).
    - Solo si no se explicó antes (`permiso_notificaciones_explicado`), el interruptor está activo y el permiso está en `denied`. Se marca con cualquier respuesta: no se insiste.
  - Interruptor propio en Perfil › Preferencias (`NotificationSettingsTile` con `AppSwitchTile`, `NotificationSettingsViewModel`), guardado en `notificaciones_presupuesto`.
    - Apagado o sin permiso, se registra sin notificar: al activarlo no llegan avisos viejos.
    - Activarlo pide el permiso. Con negado permanente o restringido ofrece "Abrir Ajustes", y al volver a primer plano se revisa.
  - Al borrar los datos locales, `FileLocalDataWiper` llama a `cancelNotifications` (errores ignorados). El registro y los ajustes se van con la base.
  - Limitaciones (docs/07 §7.4):
    - Sin trabajo en segundo plano.
    - Otro celular puede repetir una alerta una vez.
    - Sin notificaciones antes de la primera sincronización.
    - Solo el mes actual.
- Señal de conexión (6B, docs/07 §7.8):
  - `NetworkMonitor` (`core/sync/network_monitor.dart`, connectivity_plus).
  - `SyncState` tiene `hasNetwork` y `lastAttemptOffline`; `isOffline` es `!hasNetwork || lastAttemptOffline`, así que `MainShell` y el Perfil no cambiaron.
  - Sin red: aviso inmediato y sin backoff (queda el intervalo de 5 min).
  - Al volver la red: `reconnectDebounce` de 2 s (cada cambio reinicia la espera), se reinicia el backoff y, si hay una sincronización en curso, se repite al terminar.
  - El aviso solo se quita con una sincronización `ok`.
  - Sin sesión lista (cierre de sesión, otro usuario, borrado) o con una base nueva, `SyncController` vuelve al estado inicial y olvida `lastSyncedAt`: la siguiente cuenta no ve en el Perfil la hora de sincronización de la anterior.
  - Solo se escucha con `syncAutoTriggersProvider`. `TestSession` trae `FakeNetworkMonitor`, `FakeBudgetAlertNotifier` y `FakeNotificationPermission` (concedido por defecto).
- Ingresar con huella, rostro o PIN (6C, docs/07 §7.7, docs/08 §8.8.2). Un solo ajuste controla el bloqueo al reabrir y el botón del login (cambio de diseño tras las pruebas con usuarios):
  - **Sin PIN propio** (cambia los docs anteriores): `local_auth` con `biometricOnly: false`; el sistema decide entre huella, rostro o el PIN, patrón o contraseña del celular y controla los intentos. No se guarda ningún PIN ni hash, no hay "Olvidé mi PIN" y se quitó el borrado tras 5 intentos. Motivos: menos fricción, nada que olvidar ni guardar, intentos del sistema operativo.
  - `core/security/`: `DeviceAuthenticator` (`LocalAuthDeviceAuthenticator`, resultados `DeviceAuthResult`: success, canceled, interrupted, lockedOut, noDeviceLock, failed), `AppLockStore` (`mislukas.app_lock_enabled`, leído en `main()` → `initialAppLockEnabledProvider`), `AppLockClock` (monotónico con `Stopwatch` + hora del sistema; no es `clockProvider`) y `ExternalActivityTracker`.
  - `hasDeviceLock` usa `isDeviceSupported()`: en Android es `isDeviceSecure` o biometría registrada (no existe sin bloqueo seguro), así que sin bloqueo de pantalla da false. `noCredentialsSet` al autenticar también cuenta como "sin bloqueo".
  - `AppLockController` (`auth/presentation/app_lock/`): arranque en frío con sesión (`ready` o `foreignData`) y bloqueo activo → bloqueado. Al volver, bloquea si el monotónico **o** la hora del sistema llegan a 5 min, o si la hora retrocedió. Con una acción propia de la app el límite es 30 min. Iniciar sesión con contraseña o con el botón del login (paso de `signedOut` a sesión) deja la app desbloqueada; la preferencia se vuelve a leer al iniciar sesión y al quedar `ready` (después de un borrado). La oferta (`_offerEligible`) se decide en cada recarga: después de un borrado por otra cuenta, la preferencia queda en false y se ofrece.
  - Acciones propias: `ExternalActivityTracker.run` (permiso de cámara y de notificaciones, galería y el propio diálogo del sistema) y `markLeavingForSettings` (Ajustes; vale para la siguiente salida si ocurre en 10 s). Se pasa a `PermissionHandlerCameraPermission`, `ImagePickerReceiptPicker` y `PermissionHandlerNotificationPermission`.
  - El diálogo del sistema se abre solo una vez por bloqueo; cancelar espera a "Ingresar con huella, rostro o PIN". Si el sistema lo cierra (`interrupted`) se repite al volver.
  - Sin bloqueo de pantalla, la protección se pausa: la app queda desbloqueada, la preferencia se conserva y se revisa en el siguiente bloqueo. La fila del Perfil queda desactivada con "Configura un bloqueo de pantalla en tu celular para proteger MisLukas".
  - `AppLockGate` es lo más externo del `builder`: `Offstage` + `ExcludeFocus` + `TickerMode` (el contenido conserva su estado), `UnlockScreen` con su propio `Navigator` y `PrivacyCover` (logo, sin datos) mientras la app no está `resumed`. `ForeignDataPrompt`, `WelcomeLauncher` y `NotificationTapLauncher` esperan a `contentVisible`.
  - `UnlockScreen`: "Hola, \<nombre\>", "Ingresar con huella, rostro o PIN" y "¿No eres tú? Cerrar sesión" (todos los textos del bloqueo usan "huella, rostro o PIN"; el mismo `showSignOutDialog` del Perfil, que solo ofrece conservar la sesión con la base `ready`; textos en `auth/presentation/sign_out_messages.dart`).
  - `AppLockOfferLauncher` ("Ingresa con tu huella, rostro o PIN"): después de iniciar sesión, con la primera sincronización exitosa, bienvenida `done` y cerrada (`welcomeOpenProvider`, que `WelcomeLauncher` mantiene con el Future del push: el `pop` de la bienvenida cerraba el diálogo) y con bloqueo de pantalla. "Activar" solo guarda la preferencia (`enableAfterSignIn`), **sin** el diálogo del sistema (se sentía como doble factor), y muestra "Listo. La próxima vez entrarás con tu huella, rostro o el PIN de tu celular."; aplica desde la siguiente apertura o regreso. Una vez por inicio de sesión; no se ofrece si ya está activo.
  - Perfil › Preferencias: `AppLockSettingsTile` ("Ingresar con huella, rostro o PIN"; reemplaza a "Bloqueo con tu celular"). Activar → `/profile/app-lock` (`EnableAppLockScreen` + `EnableAppLockViewModel`): contraseña con `reauthenticate` y luego el diálogo del sistema; si se cancela, se reintenta sin la contraseña. Desactivar: solo el diálogo del sistema.
  - Recientes: capa propia y `setRecentsScreenshotEnabled(false)` en Android 13+ (`MainActivity`). Sin FLAG_SECURE: las capturas siguen permitidas.
  - **La preferencia acompaña a los datos** (cambia la 6C anterior, que la conservaba como del dispositivo): sobrevive a "Cerrar sesión" que conserva la sesión, y el wiper la borra (`AppLockStore.clear`) en el borrado total, al eliminar la cuenta y en el borrado por otra cuenta. Si la heredara otra cuenta, su "Cerrar sesión" no borraría sus datos.
  - **Sesión en espera** (`parkedSessionProvider`, `auth/presentation/parked_session.dart`): id del usuario en `mislukas.parked_session_user` (`DeviceSessionStore.readParkedUser`/`writeParkedUser`/`clearParkedUser`), leído en `main()` → `initialParkedUserProvider`; si la lectura falla, se toma el id de `currentUser` (falla cerrada). `AccountSessionController` da `signedOut` si `currentUser.id` es el de la marca (no hay estado nuevo: router, sincronización y launchers ya lo tratan como sin sesión). La marca se borra sola si entra otra cuenta (se compara por id), con la contraseña del mismo usuario (`LoginViewModel`), con el botón y en el wiper. No se borra cuando la sesión desaparece: sin sesión no aplica (`savedSessionProvider` = `currentUser != null && id == marca`).
  - `AccountActions.park()`: guarda la marca (si falla, no cierra nada), luego `shutdown` de la sincronización e invalida `syncServiceProvider`. No hace push, no llama a `signOut` ni al wiper; la sesión de Supabase sigue guardada y gotrue la sigue renovando.
  - `showSignOutDialog` (`auth/presentation/widgets/sign_out_dialog.dart`) → `SignOutChoice` keep / wipe / cancel. Con `AppLockState.canKeepSession` (ajuste activo y `deviceLockAvailable == true`): "Cerrar sesión" (park) y "Cerrar sesión y borrar los datos de este celular" (borrado total, en rojo). Sin él, una sola acción: el borrado total de siempre. `ProfileViewModel.park()` y `signOut()`.
  - Login: `QuickSignInSection` (`auth/presentation/widgets/`) debajo de `LoginForm`, solo en "Iniciar sesión": separador "o" y una lista de opciones (hoy solo "Ingresar con huella, rostro o PIN"; ahí irán "Continuar con Google" y "Continuar con Apple"). Sin opciones ni aviso no ocupa espacio. El diálogo no se abre solo.
  - `QuickSignInViewModel`: `available` = `savedSessionProvider` && ajuste activo && `deviceLockAvailable == true` (se revisa al abrir y al volver a primer plano). `signIn`: diálogo del sistema ("Confirma que eres tú para ingresar", con `ExternalActivityTracker.run`) y `AuthRepository.resumeSession()` (`refreshSession`, siempre al servidor). Con `AuthFailure.sessionExpired` (nuevo: cualquier `AuthException` no reintentable; gotrue ya borró la sesión) muestra "Tu sesión expiró. Ingresa con tu correo y contraseña.", borra la marca y conserva los datos y el dueño (regla 5C). Sin red u otro error, entra igual (offline-first). Cancelado, pausado y fallo usan los textos de `UnlockScreen`.
  - Otra cuenta con la sesión en espera: su sesión reemplaza la guardada (sin revocarla en el servidor) y sigue `ForeignDataPrompt`. Registro y recuperación no cambian; si la app se cierra mientras se verifica un código de recuperación, `clearInterruptedRecovery` cierra la sesión guardada.
  - **Limitación documentada:** es una puerta de la app; el refresh token no está atado a una clave del Keystore con autenticación obligatoria. Trabajo futuro con `biometric_storage` (docs/08 §8.8.2).
  - Sin atajos para saltar el bloqueo, ni en desarrollo.
  - `TestSession` trae `MemoryAppLockStore` (apagado), `FakeDeviceAuthenticator(hasLock: false)` (sin oferta en las pruebas que no son del bloqueo) y `FakeAppLockClock`. `MemoryDeviceSessionStore` tiene `parkedUser` y `failNextParkedWrite`; `FakeAuthRepository.resumeSession` responde con `failNext` (con `sessionExpired` borra la sesión).
- Android (6C): `MainActivity` extiende `FlutterFragmentActivity`; el manifiesto declara `USE_BIOMETRIC`; `LaunchTheme` y `NormalTheme` (claro y oscuro) heredan de AppCompat, que pide local_auth para no fallar en Android 8. iOS: `NSFaceIDUsageDescription` en `Info.plist`.
- Fecha simulada solo en desarrollo: `clockProvider` usa `MonthShiftedClock` si `debugMonthOffsetProvider` es distinto de 0 y `kDebugMode`. Lo controlan "Adelantar un mes" y "Volver a la fecha real" en `DemoDataActions`; el desfase vive en memoria. Mientras está adelantada, todo lo que se guarda lleva fechas y `actualizado_en` futuros (que ganarían conflictos reales): solo se usa con una cuenta de prueba que se elimina al final.

## Stack

- **Flutter (Dart)** para Android e iOS desde un solo código. Se desarrolla en Windows; iOS se compila después en un Mac.
- **Riverpod**: manejo de estado e inyección de dependencias.
- **go_router**: navegación.
- **intl**: formato de moneda y fechas.
- **Drift (SQLite) + SQLite3MultipleCiphers**: base de datos local cifrada (Fase 4).
- **uuid**, **path_provider** y **flutter_secure_storage**: ya incorporadas en la Fase 4 (identificadores, ubicación de la base y clave de cifrado).
- **Supabase** (`supabase_flutter`, incorporado en la Fase 5A): Auth, PostgreSQL con Row Level Security y Storage (Fase 5).
- **flutter_localizations** (del SDK, incorporado en la Fase 5D): textos del sistema en español (calendario).
- **Paquetes del dispositivo** (Fase 6): `camera`, `image_picker`, `google_mlkit_text_recognition`, `flutter_local_notifications`, `local_auth`, `connectivity_plus`. En la 6A se incorporaron `camera`, `image_picker` y `google_mlkit_text_recognition`, más `permission_handler` (permiso de cámara) y `cryptography` + `cryptography_flutter` (cifrado de las imágenes), aprobados aparte. En la 6B, `flutter_local_notifications` 22.3.2 (la 23 exige compileSdk 37) y `connectivity_plus` 7.3.2. En la 6C, `local_auth` 3.0.2, con `local_auth_android` 2.3.0 y `local_auth_darwin` 2.0.5 como dependencias directas solo para los textos en español del diálogo (`AndroidAuthMessages`, `IOSAuthMessages`). Las versiones de la Fase 6 van fijas en pubspec.yaml (sin `^`). `permission_handler` va en 12.0.3: las 13.x traen `permission_handler_android` 14.x, que exige compileSdk 37, y el AGP 9.1 del proyecto recomienda como máximo 36.

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
│   ├── sync/        # (Fase 5) sincronización y señal de red
│   ├── notifications/ # (Fase 6B) notificaciones locales
│   └── errors/      # Errores y mensajes para el usuario
└── features/
    ├── auth/        # Login, registro, recuperación, desbloqueo
    ├── home/        # Inicio: disponible, alertas, últimos movimientos
    ├── movements/   # Nuevo gasto, confirmación, OCR, historial
    ├── budgets/     # Categorías, presupuestos y alertas
    ├── reports/     # Reportes por categoría y comparación mensual
    ├── simulator/   # Simulador de ahorro
    ├── onboarding/  # Bienvenida para usuarios nuevos
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
- `ReceiptPreview`: foto del recibo sobre fondo oscuro con el total resaltado como "Área detectada" (`ReceiptPreview.image(bytes, detectedArea:)`), mientras carga (`.loading()`) o sin foto (`.unavailable(notOnDevice | unreadable)`). La imagen llega en memoria; en la galería se dibuja una de muestra.
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
- `showAppConfirmDialog`: diálogo de confirmación con "Cancelar" (o `cancelLabel`, como "Ahora no") y una acción (en rojo con `destructive`); devuelve true si el usuario confirma.
- `AppSwitchTile`: ajuste con ícono, título, descripción e interruptor; toda la tarjeta lo cambia ("Notificaciones de presupuesto").
- `DemoDataActions` (`core/widgets/dev/`): "Cargar datos de demostración", "Borrar todos los datos" y la fecha simulada ("Adelantar un mes"); solo se muestra en modo desarrollo.
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
- Tokens de sesión, claves de cifrado, la marca de sesión en espera y la preferencia de bloqueo: **solo** en `flutter_secure_storage`. No hay PIN propio de la app (6C).
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

**Fase actual: 6**

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
