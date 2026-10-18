# 9. Pruebas y evidencias

Esta sección reúne las evidencias de las pruebas hechas durante el desarrollo: la verificación del esquema remoto en Supabase, las pruebas automáticas, las pruebas manuales en celulares reales y las mediciones de la Fase 6A. Lo que todavía no está registrado queda marcado **por completar**, para llenarlo con el resultado real y no con una suposición.

Las pruebas en celulares reales se hicieron en estos dispositivos:

| Dispositivo       | Gama  | Arquitectura  | Versión de Android |
| ----------------- | ----- | ------------- | ------------------ |
| Motorola moto g72 | Media | por completar | por completar      |
| Samsung Galaxy J4 | Baja  | armeabi-v7a   | por completar      |

iOS se compilará y probará después en un Mac (docs/06).

## 9.1 Esquema remoto en Supabase

`supabase/verify.sql` se ejecuta completo en el SQL Editor. La parte 1 son listados para revisar a mano (RLS activado en cada tabla, políticas, permisos por tabla y por columna, usuarios sin perfil). La parte 2 son pruebas automáticas: crea tres usuarios temporales (A, B y C) con filas de prueba, comprueba RLS, permisos y el aislamiento entre usuarios, y al final revierte todo. Cada prueba muestra OK o el error.

| Fase | Migraciones | Qué se agregó a la verificación                                                                                             | Resultado |
| ---- | ----------- | --------------------------------------------------------------------------------------------------------------------------- | --------- |
| 5B   | 001 a 008   | RLS, permisos, aislamiento entre dos usuarios, índices únicos entre activos, llave compuesta de recibos, Storage            | 48/48 OK  |
| 5C   | 001 a 009   | Última escritura gana en el servidor (`conservar_ultima_escritura`), política de delete en Storage y `eliminar_mi_cuenta()` | 65/65 OK  |

Fecha de cada ejecución: por completar.

## 9.2 Pruebas automáticas

Las pruebas de Flutter están en `test/`, con la misma estructura de `lib/`. Cubren el dominio (casos de uso, reglas del simulador, presupuestos y alertas), la base local con Drift, la sincronización contra un servidor falso (`FakeSyncServer`), el parser de recibos y las pantallas con pruebas de widget (estados, textos y pantallas pequeñas sin desbordes).

| Fecha      | Flutter | Comando                        | Resultado                   |
| ---------- | ------- | ------------------------------ | --------------------------- |
| 2026-10-18 | 3.47.5  | `flutter test --concurrency=1` | 665 pruebas, todas pasan    |
| 2026-10-18 | 3.47.5  | `flutter analyze`              | Sin errores ni advertencias |

En el computador de desarrollo la suite se ejecuta con `--concurrency=1`: con más procesos en paralelo, el equipo se queda sin memoria. El resultado es el mismo; solo tarda más (unos 5 minutos).

## 9.3 Pruebas manuales de la Fase 5

Se probaron en el moto g72 y en el Galaxy J4 con `flutter run --dart-define-from-file=env/dev.json`, contra el proyecto de Supabase de desarrollo. La columna "Qué se verifica" resume el comportamiento esperado según CLAUDE.md y docs/06 y docs/08.

| Prueba                           | Qué se verifica                                                                                                                                                 | moto g72      | Galaxy J4     |
| -------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- | ------------- |
| Registro con código              | Llega el correo con el código de 6 dígitos; con el código la cuenta queda verificada y entra a la app. Un código errado muestra error.                          | por completar | por completar |
| Recuperación de contraseña       | Mensaje genérico (no revela si el correo existe); con el código se guarda la contraseña nueva, se cierra la sesión en todos los dispositivos y vuelve a /login. | por completar | por completar |
| Sincronización                   | Un movimiento creado sin conexión queda pendiente y se envía al volver la conexión; lo creado en un celular aparece en el otro.                                 | por completar | por completar |
| Otro usuario en el mismo celular | Al entrar otra cuenta aparece el aviso de datos de otro usuario; al confirmar se borra la base local antes de abrirla.                                          | por completar | por completar |
| Eliminar cuenta                  | Pide la contraseña de nuevo, borra los archivos de Storage y la cuenta, y la app vuelve a /login sin datos locales.                                             | por completar | por completar |
| Ingresos                         | "Nuevo movimiento" › Ingreso registra valor, descripción y fecha (no futura); el disponible del mes se actualiza.                                               | por completar | por completar |
| Historial                        | "Ver todos" agrupa por mes con totales; los filtros Todos, Gastos, Ingresos y por categoría funcionan; carga más meses al llegar al final.                      | por completar | por completar |
| Presupuestos                     | Crear, editar y quitar un presupuesto desde Perfil › Presupuestos; la barra cambia a amarilla desde 75% y a roja desde 100%.                                    | por completar | por completar |
| Mes simulado (solo desarrollo)   | "Adelantar un mes" copia los presupuestos al mes nuevo sin alertas; "Volver a la fecha real" restablece la fecha. Se usó con una cuenta de prueba.              | por completar | por completar |

Fecha de las pruebas y observaciones: por completar.

## 9.4 Fase 6A: foto del recibo, OCR y cifrado

**Costo del cifrado de las imágenes.** Medido con "Medir cifrado de recibos" (Perfil, compilación `--profile`): cifra y descifra 10 veces 1 MB de bytes aleatorios con AES-256-GCM y muestra la mediana (docs/07 §7.5).

| Dispositivo                     | Compilación | Tamaño | Cifrar (mediana) | Descifrar (mediana) | Total         | Criterio | Resultado     |
| ------------------------------- | ----------- | ------ | ---------------- | ------------------- | ------------- | -------- | ------------- |
| Samsung Galaxy J4 (armeabi-v7a) | `--profile` | 1 MB   | 48 ms            | 54 ms               | 102 ms        | ≤ 300 ms | Cumple        |
| Motorola moto g72               | `--profile` | 1 MB   | por completar    | por completar       | por completar | ≤ 300 ms | por completar |

**OCR.** En el Galaxy J4, la lectura del recibo no mostró un retardo perceptible entre "Usar foto" y Confirma los datos. Con eso y la medición del cifrado se mantiene la resolución de 1080p (`ResolutionPreset.veryHigh`).

**Permisos de cámara.** Todos los caminos de docs/07 §7.9:

| Caso                     | Resultado esperado                                                                                                                        | Resultado obtenido |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------ |
| Primera vez              | "Permite el acceso a la cámara"; el diálogo del sistema solo aparece al tocar "Permitir cámara". También ofrece galería y "Ahora no".     | por completar      |
| Permiso concedido        | Se abre el visor con marco, linterna y galería.                                                                                           | por completar      |
| Permiso negado           | "No tenemos acceso a la cámara", con galería, "Permitir cámara" y "Registrar manual".                                                     | por completar      |
| Negado permanente        | "La cámara está desactivada para MisLukas": indica cómo habilitarla en Ajustes; al volver a la app con el permiso dado, se abre el visor. | por completar      |
| Bloqueado por el sistema | "La cámara no está disponible", con galería o "Registrar manual".                                                                         | por completar      |

**Modo avión.** Con el celular en modo avión se toma la foto, se lee el recibo y se guarda el gasto: queda pendiente de sincronizar y se envía al volver la conexión. Resultado: por completar.

**Borrado de archivos.** Resultado esperado según docs/07 §7.5:

| Caso                                    | Resultado esperado                                                              | Resultado obtenido |
| --------------------------------------- | ------------------------------------------------------------------------------- | ------------------ |
| Después del OCR                         | `recibos/tmp/` queda vacío; solo existe `recibos/<id>.enc`.                     | por completar      |
| "Repetir" o salir de la captura         | Se borra el temporal.                                                           | por completar      |
| Salir de Confirma los datos sin guardar | Se borra el `.enc`.                                                             | por completar      |
| Eliminar el movimiento                  | Se borra su imagen.                                                             | por completar      |
| Siguiente arranque                      | Se borran imágenes huérfanas y lo que la cámara y la galería dejan en la caché. | por completar      |
| Cerrar sesión                           | Se borran la base, la carpeta `recibos/` y las dos claves de cifrado.           | por completar      |

**Recibos reales.** La foto se toma con el recibo solo, sobre una superficie lisa y sin otros papeles alrededor (docs/07 §7.3).

| Recibo       | Frase del total | Total esperado | Total obtenido | Comercio esperado | Comercio obtenido | Categoría esperada | Categoría obtenida | Banner        |
| ------------ | --------------- | -------------- | -------------- | ----------------- | ----------------- | ------------------ | ------------------ | ------------- |
| Supermercado | por completar   | por completar  | por completar  | por completar     | por completar     | Mercado            | por completar      | por completar |
| Restaurante  | por completar   | por completar  | por completar  | por completar     | por completar     | Restaurantes       | por completar      | por completar |
| Droguería    | por completar   | por completar  | por completar  | por completar     | por completar     | Otros              | por completar      | por completar |
| Gasolina     | por completar   | por completar  | por completar  | por completar     | por completar     | Transporte         | por completar      | por completar |
| Agua         | VALOR DEL PAGO  | por completar  | por completar  | por completar     | por completar     | Servicios          | por completar      | por completar |
| Luz CENS     | VALOR PAGADO    | $116.736       | por completar  | Cens              | por completar     | Servicios          | por completar      | por completar |

El recibo de CENS se leía bien solo, pero no encima de otra factura con texto a los lados: las palabras CUOTA y SALDO de la factura de fondo, a la misma altura, descartaban la fila. Desde ese ajuste, las exclusiones se evalúan solo sobre la línea que contiene la palabra clave (docs/07 §7.3), y la indicación del visor pide el recibo solo. Resultado con el recibo encima de otro papel después del ajuste: por completar.

## 9.5 Fase 6B: alertas de presupuesto y señal de conexión

Pruebas en celulares reales con `flutter run --dart-define-from-file=env/dev.json` y una cuenta de prueba. Para el cambio de mes se usa "Adelantar un mes" (solo en modo desarrollo). En Android 13 o superior, el permiso de notificaciones empieza sin pedir; para repetir los casos se borran los datos de la app o se quita el permiso en Ajustes. El Galaxy J4 (Android 10) no pide el permiso: viene concedido.

**Permiso de notificaciones.**

| Caso | Qué se verifica | moto g72 | Galaxy J4 |
| --- | --- | --- | --- |
| Abrir la app | No se pide ningún permiso al abrir. | por completar | por completar |
| Primer presupuesto | Al guardarlo aparece "Te avisamos de tus presupuestos" con "Permitir" / "Ahora no". | por completar | no aplica |
| "Ahora no" | No aparece el diálogo del sistema; al guardar otro presupuesto no se vuelve a preguntar. | por completar | no aplica |
| "Permitir" › Permitir | Diálogo del sistema; el Perfil dice "Te avisamos al 75% y al 100%". | por completar | no aplica |
| "Permitir" › No permitir | No se vuelve a preguntar; las alertas se ven en el banner de Inicio; el Perfil dice "Permite las notificaciones del celular". | por completar | no aplica |
| Negado permanente | El Perfil dice "Desactivadas en los ajustes del celular"; "Abrir Ajustes" abre los ajustes de MisLukas y, al volver con el permiso dado, el estado se actualiza. | por completar | no aplica |
| Interruptor del Perfil | Apagado, un gasto que cruza el 75% no notifica pero se ve en Inicio; al encenderlo no llega la alerta vieja. | por completar | por completar |

**Alertas.**

| Caso | Qué se verifica | moto g72 | Galaxy J4 |
| --- | --- | --- | --- |
| 75% | Un gasto que lleva Mercado al 75% muestra "Llevas el 75% de tu presupuesto de Mercado.", sin montos. | por completar | por completar |
| Sin repetir | Otro gasto de Mercado en el mismo mes (sin llegar al 100%) no notifica. | por completar | por completar |
| 100% exacto | "Llegaste al 100% de tu presupuesto de Mercado de \<mes\>."; reemplaza a la del 75%. | por completar | por completar |
| Más de 100% de una vez | Un gasto que pasa del 74% a más del 100% notifica solo "Superaste tu presupuesto de … de \<mes\>.". | por completar | por completar |
| Baja y vuelve a subir | Eliminar el gasto y registrarlo de nuevo no repite la alerta. | por completar | por completar |
| Pantalla bloqueada | Con bloqueo seguro, la notificación no muestra el texto (visibilidad privada). | por completar | por completar |
| Tocar la notificación | Con la app abierta y con la app cerrada, abre Presupuestos; Volver regresa a donde estaba. | por completar | por completar |
| Otro celular | Un gasto registrado en el otro celular notifica en este al abrir la app y sincronizar. | por completar | por completar |
| Celular nuevo | Al iniciar sesión con datos que ya superan el 75%, no llega ninguna notificación (línea base). | por completar | por completar |
| Mes adelantado | "Adelantar un mes": el mes nuevo empieza sin alertas y vuelve a alertar al 75%. | por completar | por completar |
| Cerrar sesión | Las notificaciones de alertas que estaban a la vista desaparecen. | por completar | por completar |

**Señal de conexión.**

| Caso | Qué se verifica | moto g72 | Galaxy J4 |
| --- | --- | --- | --- |
| Modo avión | El aviso "Sin conexión" aparece de inmediato. | por completar | por completar |
| Volver la conexión | Un gasto registrado en modo avión se envía unos 2 s después de quitar el modo avión, sin esperar el reintento. | por completar | por completar |
| Red que parpadea | Activar y desactivar el Wi-Fi varias veces seguidas sincroniza una sola vez al estabilizarse. | por completar | por completar |
| Wi-Fi sin internet | Conectado a un Wi-Fi sin salida a internet (por ejemplo, el hotspot de otro celular sin datos), el aviso se mantiene. | por completar | por completar |

Fecha de las pruebas y observaciones: por completar.

## 9.6 Capturas pendientes

Pantallas que hay que fotografiar en un celular real para el informe. Conviene usar una cuenta de prueba con datos de demostración y ninguna información personal.

### Autenticación (Fase 5A)

- Inicio de sesión, con un error de credenciales.
- Registro, con la barra de fortaleza de la contraseña.
- Verificación del correo con el código de 6 dígitos.
- Recuperación de contraseña: correo, código y contraseña nueva.

### Uso diario (Fases 3 a 5)

- Inicio con disponible del mes, alertas y últimos movimientos, incluido un movimiento pendiente de sincronizar.
- Inicio sin conexión (`AppOfflineIndicator`).
- Nuevo movimiento: Gasto (foto o manual) e Ingreso.
- Confirma los datos en la variante manual ("Registra tu gasto").
- Historial agrupado por mes, con un filtro aplicado.
- Reportes: dona por categoría y comparación mensual.
- Simulador de ahorro con el aviso de la tasa.
- Bienvenida: paso 1 (ingresos) y paso 2 (presupuestos).
- Presupuestos: tarjetas en azul, amarillo y rojo, y una tarjeta en edición.

### Perfil y cuenta (Fase 5C)

- Perfil con el estado de la sincronización.
- Aviso de datos de otro usuario en el mismo celular.
- Confirmación de cierre de sesión con pendientes sin enviar.
- Eliminar cuenta.

### Foto del recibo (Fase 6A)

- Explicación previa del permiso de cámara.
- Permiso negado y negado permanente (Ajustes).
- Visor de cámara con el marco y la indicación.
- "Usar foto" / "Repetir" y "Leyendo tu recibo…".
- Confirma los datos con el banner verde, el amarillo y el rojo.
- Recibo sin foto en este celular ("La foto solo está en el celular donde se tomó").
- Resultado de "Medir cifrado de recibos" en el Galaxy J4.

### Alertas y conexión (Fase 6B)

- Explicación previa del permiso de notificaciones.
- Notificación del 75% y del 100% en la barra de notificaciones.
- Notificación en la pantalla de bloqueo (sin el texto).
- Perfil › Preferencias con el interruptor "Notificaciones de presupuesto" en sus estados.
- Inicio con el aviso "Sin conexión" en modo avión.

### Supabase

- Resultado de `verify.sql` con todas las filas en OK (65/65).
- Tablas con RLS activado (listado 1.1 de `verify.sql`).
