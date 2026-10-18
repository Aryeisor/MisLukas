# 7. Funcionalidades del dispositivo móvil utilizadas

Una aplicación móvil tiene a su alcance capacidades que un sitio web no ofrece, o que ofrece de forma limitada: la cámara, el procesamiento de imágenes en el propio equipo, las notificaciones, el almacenamiento protegido por el sistema operativo o la autenticación biométrica. MisLukas aprovecha estas capacidades con un criterio claro: cada una debe resolver una necesidad concreta del usuario identificada en las secciones anteriores, y ninguna se usa solo porque está disponible.

Esta sección describe cada funcionalidad del dispositivo que usa la aplicación, cómo se integra en el flujo del usuario y qué decisiones se tomaron para usarla de forma segura. Al final se detallan los permisos que la aplicación solicita.

| Funcionalidad             | Paquete de Flutter            | Necesidad que resuelve                            | Requisitos relacionados |
| ------------------------- | ----------------------------- | ------------------------------------------------- | ----------------------- |
| Cámara                    | camera                        | Capturar el recibo en el momento de la compra     | RF-14, RNF-12           |
| Galería                   | image_picker                  | Usar una foto del recibo tomada antes             | RF-14                   |
| Permiso de cámara         | permission_handler            | Pedir el permiso en el momento y abrir Ajustes    | RF-14                   |
| OCR en el dispositivo     | google_mlkit_text_recognition | Extraer el valor y el comercio sin escribirlos    | RF-15, RF-16, RNF-13    |
| Cifrado de las imágenes   | cryptography + cryptography_flutter | Guardar las fotos de recibos cifradas (AES-GCM) | RNF-04, RNF-05          |
| Notificaciones locales    | flutter_local_notifications   | Avisar antes de pasarse del presupuesto           | RF-32                   |
| Almacenamiento interno    | path_provider + Drift         | Guardar datos e imágenes disponibles sin conexión | RF-24, RNF-09           |
| Almacenamiento seguro     | flutter_secure_storage        | Proteger tokens y la clave de cifrado             | RNF-04, RNF-05          |
| Biometría y PIN           | local_auth                    | Desbloquear rápido sin exponer los datos          | RF-12, RNF-08           |
| Detección de conectividad | connectivity_plus             | Sincronizar automáticamente al volver la conexión | RF-25, RNF-10           |

## 7.1 Cámara: captura del recibo

La cámara es la puerta de entrada de la funcionalidad principal de MisLukas. Cuando el usuario elige "Foto del recibo" y toca "Continuar", la aplicación abre una vista de cámara propia, integrada en la app, en lugar de enviar al usuario a la aplicación de cámara del sistema.

**Por qué una cámara integrada.** Abrir la cámara del sistema implica salir de MisLukas, tomar la foto, confirmarla y volver, con pasos adicionales que alargan el registro. Una vista integrada permite guiar al usuario y mantener el flujo dentro de la aplicación, lo que es clave para cumplir la meta de registrar un gasto en menos de 15 segundos (RNF-12).

**Cómo funciona.**

- **Guía de encuadre.** La vista muestra un marco con esquinas resaltadas y el texto "Ubica el recibo dentro del marco, sobre una superficie lisa y sin otros papeles", que ayuda a obtener una imagen más legible y evita que el OCR lea el texto de otro papel (7.3).
- **Controles.** Incluye un botón de linterna para lugares con poca luz, habituales en el momento de pagar, y un acceso rápido a la galería.
- **Revisión.** Después de la captura se muestra la foto durante un instante con las opciones "Usar foto" y "Repetir", para descartar imágenes borrosas antes de procesarlas.
- **Optimización.** La imagen se redimensiona y comprime antes de pasar al OCR. Una resolución más baja sigue siendo suficiente para leer el texto y reduce el tiempo de procesamiento y el espacio ocupado.

**Manejo de la imagen.** La foto se guarda en el directorio privado de la aplicación, al que otras aplicaciones no tienen acceso. **No se guarda en la galería del usuario**, para no mezclar recibos con sus fotos personales ni exponerlos a aplicaciones que tengan acceso a la galería. Si el usuario cancela el registro, la imagen temporal se elimina.

**Implementación (Fase 6A).**

- **Visor propio con camera, no la cámara del sistema.** Además de las razones anteriores, en un celular con poca memoria (por ejemplo, un Galaxy J4) Android puede cerrar MisLukas mientras la app de cámara del sistema está abierta, y el usuario perdería el registro.
- **Resolución y formato.** La cámara usa `ResolutionPreset.veryHigh` (1080p) y JPEG, sin audio: la app no pide el micrófono. Esa resolución basta para que el OCR lea el texto pequeño del recibo, y la foto pesa entre 300 KB y 1 MB. No se vuelve a comprimir, porque eso necesitaría otro paquete. La medición en un Galaxy J4 confirmó los 1080p (7.5); si otro celular lo exigiera, se baja a 720p cambiando una constante (`receipt_capture_settings.dart`).
- **Ciclo de vida.** El controlador de la cámara se libera cuando la app pasa a segundo plano y se crea de nuevo al volver, como pide el paquete.
- **Archivo temporal.** La cámara deja la foto en la caché. La app la mueve de inmediato a `recibos/tmp/` en su almacenamiento privado; la imagen sin cifrar solo existe ahí hasta que termina el OCR (7.5). "Repetir", salir de la pantalla o un error la borran.
- **Flujo.** Nuevo movimiento › Foto del recibo › Continuar abre `/movements/new/receipt`. Con "Usar foto" se muestra "Leyendo tu recibo…" mientras corren el OCR y el cifrado, y después Confirma los datos reemplaza a la captura: Volver lleva a Nuevo movimiento.

## 7.2 Galería: subir una foto existente

No siempre es posible fotografiar el recibo en el momento. Muchas personas toman la foto rápido para registrarla después, o reciben el recibo como imagen por correo o por un chat. Para esos casos, desde la vista de cámara se puede abrir la galería y seleccionar una imagen.

**Uso del selector del sistema.** La selección se hace con el selector de fotos que ofrece el propio sistema operativo, mediante image_picker. Con este mecanismo, la aplicación solo recibe la imagen que el usuario eligió, no acceso a toda su galería. En las versiones actuales de Android e iOS, esto permite seleccionar la foto sin conceder un permiso amplio sobre la biblioteca de imágenes. Es la opción más respetuosa con la privacidad: MisLukas no necesita ver las fotos del usuario, solo la del recibo.

Una vez seleccionada, la imagen sigue exactamente el mismo proceso que una foto tomada con la cámara: se copia al directorio privado de la aplicación, se optimiza y pasa al reconocimiento de texto.

**Implementación (Fase 6A).** `pickImage` se llama con `maxWidth` y `maxHeight` de 1920 px, calidad JPEG 85 y `requestFullMetadata: false`, que en iOS evita pedir el permiso de la biblioteca. En Android, image_picker copia la foto a la caché y deja aparte la versión reducida; la copia original se borra de inmediato. Una foto de la galería no pasa por "Usar foto" / "Repetir", porque el usuario ya la eligió. Si después de reducirla pesa más de 5 MB (el límite del bucket de Storage), se muestra "La imagen es muy grande".

## 7.3 OCR en el dispositivo: extracción del valor y el comercio

El reconocimiento óptico de caracteres (OCR) convierte la imagen del recibo en texto que la aplicación puede interpretar. MisLukas utiliza el reconocimiento de texto de Google ML Kit, que **se ejecuta completamente en el dispositivo** con un modelo incluido en la aplicación.

**Por qué en el dispositivo y no en la nube.** Existen servicios de OCR en la nube con mayor precisión en algunos casos, pero descartamos esa opción por tres razones:

- Requieren conexión, lo que contradice el enfoque offline-first.
- Implican enviar la foto del recibo a un servidor externo, con el riesgo de privacidad que eso supone.
- Dependen de la velocidad de la red, lo que haría variable el tiempo de lectura.

Con el procesamiento local, la lectura funciona en cualquier lugar, la imagen no sale del celular y el tiempo de respuesta es predecible (RNF-13).

**Proceso de extracción.** ML Kit entrega el texto del recibo organizado en bloques y líneas. A partir de ahí, la aplicación aplica su propia lógica de interpretación, implementada como un caso de uso de la capa de dominio:

1. **Filas del recibo.** ML Kit puede entregar "TOTAL" y "\$87.400" en bloques distintos cuando están en columnas. Con la ubicación de cada línea, la aplicación las agrupa en filas visuales (líneas a la misma altura, de izquierda a derecha).
2. **Detección del total.** Se buscan las filas con palabras clave, sin importar mayúsculas, tildes ni espacios extra, y corrigiendo el cero leído en lugar de la letra O ("VAL0R PAGAD0"). Van de la más fuerte a la más débil:
   - **Lo que se paga o ya se pagó:** "TOTAL A PAGAR", "VALOR A PAGAR", "TOTAL PAGAR", "NETO A PAGAR", "GRAN TOTAL", "TOTAL CON PROPINA", "TOTAL GENERAL", "VALOR PAGADO", "TOTAL PAGADO", "SALDO PAGADO", "MONTO PAGADO", "VALOR DEL PAGO", "VALOR PAGO", "PAGO TOTAL", "TOTAL A CANCELAR", "VALOR A CANCELAR", "PAGUE ESTE VALOR", "TOTAL PAGO OPORTUNO" y "PAGO OPORTUNO".
   - **Totales de la factura:** "VALOR TOTAL", "TOTAL FACTURA", "TOTAL FACTURADO", "VALOR FACTURA", "VALOR TOTAL FACTURA", "TOTAL VENTA", "TOTAL COMPRA", "IMPORTE TOTAL", "MONTO TOTAL", "IMPORTE" y "MONTO".
   - **Por último:** "TOTAL" y "NETO".

   "VALOR" y "SALDO" solos no son palabras clave, porque acompañan a casi cualquier fila de una factura de servicios. Se descartan las filas de subtotal, IVA, base gravable, impoconsumo, propina, descuentos, pago en efectivo, cambio y conteo de productos (salvo en las palabras clave más fuertes, como "TOTAL CON PROPINA"). También se descartan siempre, incluso con las palabras clave más fuertes, las filas de valor unitario, valor del kWh, valor del consumo, subsidio, contribución, IVA, mora e intereses de mora, recargo ("PAGO CON RECARGO"), saldo anterior, saldo pendiente, saldo a favor, pago mínimo, cuota y abono. Las palabras clave y las exclusiones se evalúan sobre la línea de ML Kit que contiene la palabra clave, no sobre toda la fila visual: si el recibo está encima de otro papel, el texto de ese papel a la misma altura (por ejemplo, "CUOTA" o "SALDO") no descarta la fila ni aporta su monto. El valor se toma de esa misma línea; si no tiene, de la siguiente línea de la fila cuando solo tiene un monto, o de la fila de abajo cuando su primera línea a partir de la palabra clave solo tiene un monto. La puntuación pegada no estorba ("PAGADO:\$116,736", "PAGADO :\$ 116,736"). La fecha se busca también línea por línea, para que un "HASTA" o un "VCTO" de otro papel no la descarte. Gana la palabra clave más fuerte y, con empate, la fila más abajo, porque en la mayoría de formatos el total final va al pie, después de subtotales e impuestos.
3. **Normalización del valor.** Los recibos colombianos escriben los montos de formas distintas: "\$87.400", "87,400", "87400", "87 400" o "87.400,00". La aplicación reconoce estos formatos, corrige la letra O leída en lugar de un cero y los convierte a un número entero de pesos. Ignora NIT, porcentajes, horas, fechas y números de tarjeta. **Si no se encuentra una palabra clave de total, el valor queda vacío** y el usuario lo escribe: proponer el número más alto acertaba a veces, pero también proponía el pago en efectivo o un NIT mal leído.
4. **Detección del comercio.** Se toma el texto de las primeras líneas del recibo, donde suele ir el nombre del establecimiento, y se compara con un diccionario local de comercios frecuentes en Colombia (supermercados, cadenas de restaurantes y cafés, estaciones de servicio, droguerías, sistemas de transporte, entre otros). Si no está en el diccionario, se usa la primera de las seis primeras filas que no sea un NIT, una dirección, un teléfono o un encabezado de factura, sin la razón social ("S.A.S.", "LTDA").
5. **Sugerencia de categoría.** Si el comercio está en el diccionario, se sugiere la categoría asociada: un supermercado sugiere Mercado y una cadena de cafés sugiere Ocio. Si no se reconoce, se revisan palabras del propio texto ("supermercado", "droguería", "restaurante") y, si aún no hay coincidencia, no se preselecciona ninguna categoría.
6. **Fecha de la compra.** Se reconocen "17/10/2026", "17-10-26", "17.10.2026", "2026-10-17" y "17 OCT 2026", siempre con el día antes que el mes. Se prefiere la fila que dice "FECHA" y se ignoran las de la resolución de la DIAN, vigencias, vencimientos, fecha límite de pago y periodos facturados. **Una fecha futura, inexistente o anterior a 2000, o un recibo sin fecha, deja la fecha de hoy.**
7. **Resultado para el usuario.** La pantalla "Confirma los datos" muestra el valor, el comercio, la categoría sugerida, la fecha y la imagen con el área del total resaltada. El usuario siempre puede corregir todo antes de guardar (RF-17). Un banner indica el resultado de la lectura: verde ("Recibo leído correctamente") si se encontró el total; amarillo ("No encontramos el total") si se leyó el recibo, pero no el total; rojo ("No pudimos leer el recibo. Puedes ingresar el valor manualmente") si no se leyó nada o el OCR falló. En los dos últimos, el flujo sigue de forma manual (RF-18).

**Qué se conserva del texto.** El parser es Dart puro, en la capa de dominio (`ReceiptParser`), y no depende de ML Kit. De todo el texto reconocido solo se conservan el total, el comercio, la fecha, la categoría y la zona del total en la imagen; el resto se descarta en memoria (docs/08 §8.9.3). En el recibo se guardan `total_detectado` y `comercio_detectado` tal como se leyeron, aunque el usuario los corrija en el movimiento. El texto del recibo, los montos y las rutas de archivo nunca se escriben en los registros.

**Por qué reglas y no inteligencia artificial para la categoría.** Para el MVP, un diccionario de comercios y palabras clave es suficiente, transparente y funciona sin conexión. Un modelo de clasificación entrenado podría mejorar la precisión, pero requiere datos de entrenamiento que el proyecto aún no tiene. A futuro, la sugerencia podría aprender de las correcciones del usuario: si siempre cambia un comercio de Otros a Restaurantes, la próxima vez se sugiere Restaurantes.

**Limitaciones conocidas.** La calidad de la lectura depende de la imagen. Los recibos arrugados, los de papel térmico desteñido, los escritos a mano y las fotos con poca luz o movidas pueden producir lecturas incorrectas o incompletas. La aplicación contempla estos casos de tres formas:

- La guía de encuadre y la linterna mejoran la captura.
- **La foto debe tomarse con el recibo solo, sobre una superficie lisa y sin otros papeles alrededor**, como lo indica el visor. El OCR lee todo el texto de la imagen: aunque el parser evalúa cada línea por separado, el total de otro recibo o de una factura que aparezca junto a él puede tomarse como el valor.
- El valor siempre es editable.
- Si no se detecta ningún valor, se informa al usuario y se le permite ingresarlo manualmente (RF-18).

La función está pensada para ahorrar trabajo en la mayoría de los casos, no para ser infalible, y el diseño asume que el usuario tiene la última palabra.

## 7.4 Notificaciones locales: alertas de presupuesto

Las alertas de presupuesto son más útiles si llegan en el momento preciso, aunque el usuario no esté mirando la pantalla de inicio. Para eso, MisLukas usa notificaciones del sistema.

**Por qué locales y no push.** Las notificaciones push se envían desde un servidor, lo que requeriría que el servidor calcule los presupuestos de cada usuario y que el dispositivo tenga conexión para recibirlas. En MisLukas, el cálculo del presupuesto ya ocurre en el dispositivo cada vez que se guarda un movimiento. Por eso la notificación se genera ahí mismo: funciona sin conexión, llega de inmediato y no requiere infraestructura adicional en el servidor.

**Cuándo se generan.** Cada vez que cambian los gastos o los presupuestos del mes actual, el caso de uso NotificarAlertasDePresupuesto (`NotifyBudgetAlerts`) calcula el porcentaje usado de cada presupuesto. Así se cubren todos los casos:

- registrar, editar o eliminar un gasto;
- crear, cambiar o quitar un presupuesto;
- los gastos que llegan por sincronización desde otro celular.

También se evalúa después de cada sincronización. Los ingresos no cuentan. Si un gasto cruza un umbral, se genera la alerta:

| Umbral              | Mensaje                                                     |
| ------------------- | ----------------------------------------------------------- |
| 75% del presupuesto | "Llevas el 78% de tu presupuesto de Mercado."               |
| Exactamente 100%    | "Llegaste al 100% de tu presupuesto de Mercado de octubre." |
| Más de 100%         | "Superaste tu presupuesto de Mercado de octubre."           |

El título es "Alerta de presupuesto". El porcentaje es el real (división entera: 74,9% no alerta). El monto restante solo se ve dentro de la app, en el banner de Inicio.

**Evitar el exceso de notificaciones.** Una aplicación que notifica demasiado termina silenciada o desinstalada. Por eso cada alerta se envía **una sola vez por categoría, por umbral y por mes**. Si Camila ya recibió la alerta del 75% en mercado, no la volverá a recibir con cada compra; la siguiente será la del 100%, si llega a ocurrir.

- **Un gasto que cruza los dos umbrales a la vez** muestra solo la del 100%, pero los dos quedan registrados.
- **Si el gasto baja después de alertar** (se elimina un movimiento) **o el límite sube**, el umbral no se vuelve a alertar ese mes.
- **El mes siguiente** se alerta de nuevo, porque las alertas se evalúan con los presupuestos y gastos de cada mes.
- **La notificación del 100% reemplaza a la del 75%** de la misma categoría y mes: el id de la notificación es fijo para cada categoría y mes.

**Registro de alertas enviadas (Fase 6B).** Lo enviado se guarda en la tabla local `alertas_enviadas` (categoría, mes, umbral, fecha), en la base cifrada, sin sincronizar (docs/06 §6.4.3).

- **Línea base.** La primera vez que se evalúa en una base (celular nuevo, otro usuario o la actualización a la 6B) se registra todo lo ya cruzado sin notificar. Así lo que llega del servidor en el primer pull no produce una ráfaga de avisos. Para que la línea base incluya los datos del servidor, no se evalúa nada hasta la primera sincronización exitosa de la sesión.
- **Registrar antes de notificar.** Una alerta se muestra como mucho una vez, aunque la notificación falle.
- Se borra con la base al cerrar sesión o al entrar otro usuario.

**Interruptor en el Perfil.** Perfil › Preferencias › "Notificaciones de presupuesto" las activa o desactiva (ajuste local `notificaciones_presupuesto`). Su descripción indica el estado:

| Estado                     | Descripción                                                                  |
| -------------------------- | ---------------------------------------------------------------------------- |
| Activadas, con permiso     | "Te avisamos al 75% y al 100%"                                               |
| Sin permiso                | "Permite las notificaciones del celular" (al activarlas se pide el permiso) |
| Negado de forma permanente | "Desactivadas en los ajustes del celular" (ofrece "Abrir Ajustes")          |
| Desactivadas               | "Desactivadas. Las alertas se ven en Inicio"                                 |

Sin el interruptor o sin permiso, las alertas se siguen registrando: al activarlas no llegan avisos viejos. Dentro de la app, las alertas se ven siempre en Inicio.

**Privacidad en la pantalla de bloqueo.** Las notificaciones pueden aparecer con el celular bloqueado y a la vista de otras personas.

- **Ningún texto lleva montos**, ni siquiera con el celular desbloqueado: solo el porcentaje, la categoría y el mes.
- **Visibilidad privada.** Se configuran con `NotificationVisibility.private`: en una pantalla de bloqueo segura, Android oculta el texto.
- **Payload sin datos.** Es solo la ruta de Presupuestos (docs/08 §8.8.3.1).

**Al tocar la notificación** se abre Presupuestos (`/profile/budgets`) encima de donde estaba el usuario, con la app abierta o cerrada, una vez que la sesión está lista (`NotificationTapLauncher`). **En la Fase 6C, este camino deberá pasar primero por el desbloqueo con PIN o biometría.**

**Implementación.**

- **Paquete.** flutter_local_notifications 22.3.2 (compileSdk 36, minSdk 24), con un canal "Alertas de presupuesto" de importancia normal. La 23 exige compileSdk 37.
- **Desugaring.** El plugin exige core library desugaring (`desugar_jdk_libs` 2.1.4 en `android/app/build.gradle.kts`).
- **Ícono.** `res/drawable/ic_stat_alerta.xml` es un ícono monocromo para la barra de estado. `res/raw/keep.xml` evita que la reducción de recursos del build release lo quite.
- **Sin programación.** Las notificaciones no se programan: el manifiesto combinado no tiene alarmas exactas, arranque del sistema, pantalla completa ni servicios en primer plano.

**Limitaciones conocidas.**

- **Sin segundo plano.** No hay trabajo en segundo plano: las alertas se evalúan solo con la app abierta. Un gasto registrado en otro celular se notifica cuando esta app se abre y sincroniza.
- **Otro celular puede repetir una alerta.** El registro es local, así que en otro celular una alerta puede repetirse una vez. Si se guardara en Supabase, igual se repetiría cuando los dos celulares alertan sin conexión, y costaría otra tabla en la sincronización.
- **Sin notificaciones antes de la primera sincronización.** Un usuario que nunca ha sincronizado (sin conexión desde el primer uso) no recibe notificaciones hasta su primera sincronización exitosa. Dentro de la app sí ve las alertas.
- **Solo el mes actual.** Cambiar un gasto de un mes pasado no notifica.
- **Cambio de mes con la app abierta.** Se detecta en la siguiente sincronización, cada 5 minutos como máximo.

**Prueba del cambio de mes.** En modo desarrollo, "Adelantar un mes" (Perfil) cambia el reloj: la evaluación pasa al mes nuevo, que empieza sin alertas.

## 7.5 Almacenamiento interno: base cifrada e imágenes

Cada aplicación móvil tiene un espacio de almacenamiento privado dentro del dispositivo, aislado de las demás aplicaciones por el propio sistema operativo. MisLukas guarda en ese espacio:

- **La base de datos SQLite**, cifrada con SQLite3MultipleCiphers, con los movimientos, categorías, presupuestos, datos de recibos y la cola de sincronización (sección 6.5).
- **Las imágenes de los recibos**, en una carpeta propia de la aplicación.
- **Las preferencias no sensibles**, como la última pestaña visitada.

**Protección frente a copias de seguridad.** Los sistemas operativos pueden incluir los datos de las aplicaciones en las copias de seguridad automáticas del dispositivo. Para evitar que la base de datos y las imágenes de los recibos terminen en una copia fuera del control de la aplicación, se excluyen de las copias de seguridad del sistema. En Android se desactivaron las copias de seguridad automáticas (android:allowBackup="false") y se definieron reglas de extracción de datos que excluyen la información de la aplicación de la copia en la nube y de la transferencia entre dispositivos. En iOS, la exclusión del archivo de la base de datos queda pendiente para cuando la aplicación se compile en macOS. Esto no implica pérdida de información para el usuario, porque sus datos ya se respaldan en Supabase mediante la sincronización. Aun si el archivo de la base llegara a copiarse, sin la clave de cifrado sería ilegible.

**Imágenes de recibos cifradas (Fase 6A).** Una foto de recibo es un dato financiero: muestra montos, el comercio y a veces un NIT, una cédula o los últimos dígitos de la tarjeta, y conserva todo el texto que la aplicación descarta. Por eso se guarda cifrada:

- **Algoritmo.** AES-256-GCM, cifrado autenticado, con cryptography y cryptography_flutter. Este último usa la implementación nativa del sistema (javax.crypto en Android, CryptoKit en iOS), con aceleración por hardware incluso en celulares de gama baja.
- **Clave propia.** Una clave aleatoria de 32 bytes, distinta de la de la base, guardada solo en el almacenamiento seguro (`ReceiptKeyStore`). Se crea la primera vez que se guarda un recibo. La creación es idempotente: dos guardados seguidos usan la misma clave.
- **Formato.** Cada imagen es un archivo `recibos/<id del recibo>.enc` con `nonce (12 bytes) ‖ texto cifrado ‖ MAC (16 bytes)`, con un nonce aleatorio por imagen. El id del recibo va como dato asociado: un archivo cambiado de nombre o de recibo no se descifra. Se escribe en un archivo temporal y se renombra, para no dejar archivos a medias.
- **Ruta relativa.** `recibos.ruta_local` guarda `recibos/<id>.enc`, relativa al directorio de soporte de la app, porque la ruta absoluta puede cambiar (en iOS, al actualizar la app).
- **La imagen sin cifrar solo existe durante el OCR**, porque ML Kit lee desde un archivo. Va en `recibos/tmp/` y se borra en cuanto termina el cifrado, también si el OCR o el cifrado fallan, si el usuario repite la foto o si sale de la pantalla.
- **Vista previa en memoria.** Confirma los datos descifra la imagen en memoria y la muestra con `Image.memory`. El archivo descifrado nunca se escribe en disco.
- **Sin foto.** Si el recibo no tiene imagen en este celular (por ejemplo, llegó por sincronización desde otro), se muestra "La foto solo está en el celular donde se tomó". Si no se puede descifrar, se muestra "No pudimos mostrar la foto del recibo". La pantalla sigue funcionando.
- **Limpieza.** Una vez por arranque, cuando la sesión queda lista, se borran las imágenes sin un recibo activo (de un registro interrumpido o de recibos eliminados), lo que quede en `recibos/tmp/` y las fotos que la cámara o la galería dejaron en la caché. Los recibos en curso (captura o confirmación abiertas) nunca se tocan. Eliminar un movimiento también borra su imagen.
- **Costo.** Se mide en el celular con "Medir cifrado de recibos" (Perfil, solo en modo desarrollo y `--profile`): cifra y descifra 10 veces 1 MB de bytes aleatorios y muestra la mediana. Se acepta hasta 300 ms entre cifrar y descifrar; si un celular de gama baja lo supera, se baja la resolución a 720p. Medición en un celular de gama baja:

  | Dispositivo                     | Compilación | Tamaño | Cifrar (mediana) | Descifrar (mediana) | Total  | Criterio |
  | ------------------------------- | ----------- | ------ | ---------------- | ------------------- | ------ | -------- |
  | Samsung Galaxy J4 (armeabi-v7a) | `--profile` | 1 MB   | 48 ms            | 54 ms               | 102 ms | ≤ 300 ms |

  Mediana de 10 corridas. El total queda en un tercio del criterio y el OCR no mostró un retardo perceptible en el mismo celular (RNF-13), así que se mantiene la resolución de 1080p.

**Espacio ocupado.** Los datos estructurados ocupan muy poco espacio: miles de movimientos caben en unos pocos megabytes. Las imágenes son lo que más crece, por eso se comprimen al guardarse. En una versión futura se podrá configurar que las imágenes de recibos con más de cierto tiempo se eliminen del dispositivo, conservando los datos del movimiento.

**Al cerrar sesión o eliminar la cuenta**, la aplicación borra la base de datos local, las imágenes y las claves de cifrado de la base y de las imágenes, de modo que no quede información financiera en el dispositivo (RF-13, RF-48). Las claves se borran primero: sin ellas, lo que quede de la base o de las imágenes es ilegible.

**Respaldo de las fotos en Storage (pendiente).** En la Fase 6A las fotos solo viven en el celular donde se tomaron: `ruta_storage` queda en null, en otro celular el recibo llega sin imagen y al cerrar sesión la foto se pierde. El respaldo opcional en el bucket privado `recibos` (docs/08 §8.9.3) queda para una parte posterior: necesita un ajuste en el Perfil (apagado por defecto), una cola de archivos que suba la imagen después de que la fila del recibo se sincronice, reintentos sin conexión, actualizar `ruta_storage`, borrar el objeto al eliminar el recibo y URLs firmadas para verla en otro celular. También habrá que decidir si se sube descifrada (el bucket privado acepta JPEG) o cifrada con una clave que se pueda recuperar en otro dispositivo.

## 7.6 Almacenamiento seguro del sistema: Keystore y Keychain

Hay datos que no deben guardarse ni siquiera en la base cifrada, porque son precisamente los que protegen todo lo demás. Para ellos, MisLukas usa el almacenamiento seguro que ofrece cada sistema operativo:

- **En Android, el Keystore**, que genera y guarda claves criptográficas de forma que no puedan extraerse de la aplicación. En muchos dispositivos, estas claves están respaldadas por hardware dedicado. flutter_secure_storage usa estas claves para cifrar lo que guarda.
- **En iOS, el Keychain**, el almacén cifrado del sistema para credenciales y secretos.

Qué se guarda en este almacenamiento.

| Dato                              | Por qué es crítico                                              |
| --------------------------------- | --------------------------------------------------------------- |
| Token de acceso                   | Permite hacer solicitudes a Supabase en nombre del usuario      |
| Token de renovación               | Permite obtener nuevos tokens de acceso sin pedir la contraseña |
| Clave de cifrado de la base local | Sin ella, la base de datos del dispositivo es ilegible          |
| Clave de las imágenes de recibos  | Sin ella, las fotos de recibos guardadas son ilegibles          |
| Hash del PIN de la aplicación     | Permite verificar el PIN sin guardarlo en texto plano           |

**Configuración adicional.** En iOS, los datos se configuran para que solo estén accesibles con el dispositivo desbloqueado y para que no se transfieran a otro dispositivo al restaurar una copia de seguridad. Así, los tokens y la clave de cifrado pertenecen a un dispositivo específico, y en un celular nuevo el usuario debe iniciar sesión de nuevo, como se describe en el escenario 6 de la sección 3.3.

## 7.7 Biometría o PIN: desbloqueo de la aplicación

Una vez iniciada la sesión, pedir la contraseña cada vez que se abre la aplicación sería seguro, pero tan incómodo que el usuario terminaría abandonándola. La autenticación biométrica resuelve ese equilibrio: es rápida y protege los datos si otra persona toma el celular.

**Cómo funciona.** MisLukas usa local_auth, que se apoya en la autenticación biométrica del sistema: huella dactilar en Android e iOS, y Face ID o Touch ID en iOS.

- La aplicación **nunca tiene acceso a la huella ni al rostro del usuario**. Esos datos permanecen en el hardware seguro del dispositivo, y el sistema solo le responde a la app si la verificación fue exitosa o no.
- La biometría se ofrece después del primer inicio de sesión y puede activarse o desactivarse desde el perfil (RF-46).

**El PIN como alternativa.** No todos los dispositivos tienen sensor biométrico, la biometría puede fallar (manos mojadas, poca luz, tapabocas) y algunas personas prefieren no usarla. Por eso MisLukas permite crear un PIN de cuatro dígitos propio de la aplicación, distinto del código de desbloqueo del celular.

- **El PIN nunca se guarda tal cual.** Se guarda su hash, calculado con un valor aleatorio (_salt_), en el almacenamiento seguro, y al ingresarlo se compara el hash.
- **Límite de intentos.** Después de cinco intentos fallidos, la aplicación deja de aceptar el PIN y exige iniciar sesión con correo y contraseña, lo que requiere conexión y está protegido por los límites de intentos del servidor. Así se evita que alguien pruebe todas las combinaciones posibles.

**Bloqueo automático.** La aplicación se bloquea de nuevo cuando pasa más de cinco minutos en segundo plano (RNF-08). Al volver, se solicita otra vez la biometría o el PIN antes de mostrar cualquier dato.

## 7.8 Detección de conectividad: disparo de la sincronización

Para que la sincronización sea automática, la aplicación necesita saber cuándo cambia el estado de la red. connectivity_plus informa cada vez que el dispositivo se conecta o se desconecta de una red wifi o de datos móviles.

**Un detalle técnico importante.** Estar conectado a una red no garantiza tener acceso a internet. Un celular puede estar conectado a un wifi sin salida a internet, como el de un centro comercial que exige registrarse, o a datos móviles con muy mala señal. Por eso, en MisLukas, el aviso de conectividad no se interpreta como "hay internet", sino como "vale la pena intentar sincronizar".

**Flujo.**

1. connectivity_plus informa que el dispositivo se conectó a una red.
2. El servicio de sincronización espera unos segundos para que la conexión se estabilice.
3. Intenta la sincronización (sección 6.6.2). Si la solicitud a Supabase falla, lo interpreta como falta de internet real, deja los cambios pendientes en la cola y programa un nuevo intento con esperas crecientes.
4. Si la sincronización es exitosa, actualiza el indicador de estado y retira el aviso de "Sin conexión" de la interfaz.

Además del cambio de red, la sincronización también se intenta al abrir la aplicación y periódicamente mientras está en uso, para cubrir los casos en que la conexión mejora sin que cambie el tipo de red.

**Implementación (Fase 6B).**

- **Paquete y monitor.** connectivity_plus 7.3.2, detrás de `NetworkMonitor` (`core/sync/network_monitor.dart`). Hay red si algún resultado no es `none`. ACCESS_NETWORK_STATE es un permiso normal, sin diálogo.
- **Aviso combinado.** El aviso "Sin conexión" (`AppOfflineIndicator` y el banner del Perfil) se muestra si no hay red **o** si el último intento falló por la red: `isOffline = !hasNetwork || lastAttemptOffline`.
  - Al perder la red, el aviso aparece de inmediato.
  - Al recuperarla, el aviso no se quita: solo lo quita una sincronización exitosa, porque tener Wi-Fi no garantiza internet.
- **Sin red no se reintenta.** Se cancela el reintento con esperas crecientes (5, 10, 20, 40 y 60 s) y queda solo el intervalo de 5 minutos.
- **Al recuperar la red**, se sincroniza 2 s después del último cambio (`reconnectDebounce`):
  - No se espera el backoff ni el intervalo.
  - Si la red parpadea, cada cambio reinicia la espera y se sincroniza una sola vez.
  - Si ya hay una sincronización en curso, se repite al terminar.
  - El contador del backoff vuelve a cero.

## 7.9 Permisos

Los sistemas operativos móviles protegen las capacidades sensibles del dispositivo mediante permisos que el usuario debe conceder. La forma en que una aplicación pide estos permisos influye directamente en la confianza del usuario: una aplicación de finanzas que pide acceso a todo apenas se abre genera desconfianza, y con razón.

7.9.1 Criterios para solicitar permisos

- **Solo lo necesario.** MisLukas no solicita acceso a contactos, ubicación, micrófono, llamadas ni a la galería completa, porque ninguna funcionalidad lo requiere.
- **En el momento en que se necesita.** Ningún permiso se pide al abrir la aplicación por primera vez. Cada uno se solicita justo cuando el usuario intenta usar la función que lo requiere, de modo que entiende por qué se le pide.
- **Con una explicación previa.** Antes del cuadro de diálogo del sistema, la aplicación muestra una pantalla breve que explica para qué necesita el permiso. Si el usuario no está listo, puede decir "Ahora no" sin que el sistema registre una negación.
- **Sin bloquear la aplicación.** Negar un permiso nunca impide usar MisLukas; solo desactiva la función específica y ofrece una alternativa.

7.9.2 Tabla de permisos

| Permiso                                                                                             | Plataforma    | Para qué se usa                                          | Cuando se solicita                                                                                                                                                    | Qué pasa si el usuario lo niega                                                                                                                                                             |
| --------------------------------------------------------------------------------------------------- | ------------- | -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Cámara (CAMERA en Android; NSCameraUsageDescription en iOS)                                         | Android e iOS | Tomar la foto del recibo                                 | La primera vez que el usuario elige "Foto del recibo" y toca "Continuar"                                                                                              | La app ofrece seleccionar una foto de la galería o registrar el gasto manualmente. Si el permiso se negó de forma permanente, se muestra un botón que lleva a la configuración del sistema. |
| Selección de fotos (selector del sistema; NSPhotoLibraryUsageDescription declarado en iOS)          | Android e iOS | Elegir una foto del recibo ya tomada                     | Al tocar el acceso a la galería desde la vista de cámara                                                                                                              | En las versiones actuales del sistema, el selector no requiere un permiso amplio. Si se limita el acceso, el usuario puede usar la cámara o el registro manual.                             |
| Notificaciones (POST_NOTIFICATIONS en Android 13 o superior; autorización de notificaciones en iOS) | Android e iOS | Enviar alertas de presupuesto                            | La primera vez que el usuario define un presupuesto, momento en que la alerta empieza a tener sentido                                                                 | Las alertas se siguen mostrando dentro de la app, en la pantalla de inicio. Solo se pierden los avisos fuera de ella. Se pueden activar después desde el perfil.                            |
| Biometría (USE_BIOMETRIC en Android; NSFaceIDUsageDescription en iOS)                               | Android e iOS | Desbloquear la app con huella o rostro                   | Después del primer inicio de sesión, al ofrecer activar el desbloqueo biométrico. En Android se concede al instalar; en iOS, Face ID pide confirmación la primera vez | El desbloqueo se hace con el PIN de la aplicación. Se puede activar después desde el perfil.                                                                                                |
| Internet (INTERNET)                                                                                 | Android       | Comunicarse con Supabase: autenticación y sincronización | Se concede al instalar, sin diálogo para el usuario                                                                                                                   | No aplica: es un permiso normal que el usuario no puede negar individualmente.                                                                                                              |
| Estado de la red (ACCESS_NETWORK_STATE)                                                             | Android       | Detectar cambios de conectividad para sincronizar        | Se concede al instalar, sin diálogo para el usuario                                                                                                                   | No aplica.                                                                                                                                                                                  |

En iOS, las claves NSCameraUsageDescription, NSPhotoLibraryUsageDescription y NSFaceIDUsageDescription se declaran en el archivo de configuración de la aplicación junto con un texto que el sistema muestra al pedir el permiso. Estos textos se redactan en español y explican el propósito concreto, por ejemplo: _"MisLukas usa la cámara para tomar la foto de tus recibos y leer el valor automáticamente. Las fotos no se comparten ni se guardan en tu galería."_ Apple revisa estos textos durante la publicación y puede rechazar una aplicación cuyas descripciones sean vagas.

7.9.2.1 Implementación del permiso de cámara (Fase 6A)

El permiso se maneja con permission_handler (versión 12.0.3, la última que compila contra el SDK 36 del proyecto), porque el paquete camera solo lo pide al iniciar la cámara y no indica si la negación es permanente ni abre los ajustes.

| Estado del permiso | Qué ve el usuario |
| --- | --- |
| Concedido | La cámara, directamente. |
| Sin pedir todavía | La explicación previa: "Permite el acceso a la cámara", con "Permitir cámara", "Elegir de la galería" y "Ahora no". "Ahora no" vuelve a Nuevo movimiento sin mostrar el diálogo del sistema. |
| Negado | "No tenemos acceso a la cámara", con "Elegir de la galería", "Permitir cámara" (se puede volver a pedir) y "Registrar manual". |
| Negado de forma permanente | "La cámara está desactivada para MisLukas", con los pasos (Ajustes › Aplicaciones › MisLukas › Permisos › Cámara), "Abrir Ajustes", "Elegir de la galería" y "Registrar manual". Al volver a la app se revisa el permiso otra vez. |
| Bloqueado por el sistema | "La cámara no está disponible", con la galería y el registro manual. |

En Android se quitan del manifiesto `RECORD_AUDIO` y `WRITE_EXTERNAL_STORAGE`, que agrega el plugin de CameraX, y `READ_EXTERNAL_STORAGE`, que el combinador de manifiestos agrega como implícito: MisLukas no graba audio ni guarda fotos fuera de su almacenamiento privado. La cámara se declara como no obligatoria (`android:required="false"`), porque sin ella la app sigue funcionando con la galería o el registro manual.

**Pendiente para iOS (al compilar en macOS).** Los textos `NSCameraUsageDescription` y `NSPhotoLibraryUsageDescription` ya están en `Info.plist`. Falta lo que solo se puede hacer en el Mac: activar la macro `PERMISSION_CAMERA=1` de permission_handler en el `Podfile` y fijar el mínimo de iOS que pide ML Kit (15.5).

7.9.2.2 Implementación del permiso de notificaciones (Fase 6B)

POST_NOTIFICATIONS (Android 13 o superior) se maneja con permission_handler 12.0.3 (`Permission.notification`). En Android 12 o inferior el permiso viene concedido.

**Cuándo se pide.** Nunca al abrir la app. Al guardar un presupuesto, en Presupuestos o en el paso 2 de la bienvenida, se muestra una vez la explicación previa:

- Título "Te avisamos de tus presupuestos".
- Texto "Te enviaremos una notificación al llegar al 75% y al 100% de un presupuesto. No mostramos montos."
- Botones "Permitir" / "Ahora no".

| Estado del permiso | Qué ve el usuario |
| --- | --- |
| Concedido | Nada: las alertas llegan como notificación. |
| Sin pedir todavía | La explicación previa, una sola vez. "Permitir" muestra el diálogo del sistema; "Ahora no" no lo muestra. |
| Negado (después de "Permitir" o de "Ahora no") | No se vuelve a preguntar. Las alertas se ven en el banner de Inicio. Se pueden activar desde el Perfil, que pide el permiso otra vez. |
| Negado de forma permanente o bloqueado | No se muestra la explicación. En el Perfil, "Desactivadas en los ajustes del celular" con "Abrir Ajustes"; al volver a la app se revisa otra vez. |

La marca de que la explicación ya se mostró (`permiso_notificaciones_explicado`) vive en `ajustes_locales` y se borra con la base: con otro usuario se explica de nuevo.

**Pendiente para iOS (al compilar en macOS).** La macro `PERMISSION_NOTIFICATIONS=1` de permission_handler en el `Podfile`. La inicialización de flutter_local_notifications ya tiene en `false` las solicitudes de permiso de iOS, porque el permiso lo pide permission_handler.

7.9.3 Funcionalidades que no requieren permisos

Varias de las funcionalidades descritas no requieren ningún permiso del usuario, porque operan dentro del espacio propio de la aplicación:

**OCR:** procesa imágenes que la aplicación ya tiene.

**Almacenamiento interno:** es el espacio privado de la app.

**Keystore y Keychain:** se asignan automáticamente a cada aplicación.

**Notificaciones programadas por la propia app:** solo requieren el permiso general de notificaciones.

Esto también forma parte del diseño: cuantas menos capacidades sensibles solicita una aplicación, menor es su superficie de riesgo y mayor es la confianza del usuario.
