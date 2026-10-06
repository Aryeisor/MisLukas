# 7. Funcionalidades del dispositivo móvil utilizadas

Una aplicación móvil tiene a su alcance capacidades que un sitio web no ofrece, o que ofrece de forma limitada: la cámara, el procesamiento de imágenes en el propio equipo, las notificaciones, el almacenamiento protegido por el sistema operativo o la autenticación biométrica. MisLukas aprovecha estas capacidades con un criterio claro: cada una debe resolver una necesidad concreta del usuario identificada en las secciones anteriores, y ninguna se usa solo porque está disponible.

Esta sección describe cada funcionalidad del dispositivo que usa la aplicación, cómo se integra en el flujo del usuario y qué decisiones se tomaron para usarla de forma segura. Al final se detallan los permisos que la aplicación solicita.

| Funcionalidad             | Paquete de Flutter            | Necesidad que resuelve                            | Requisitos relacionados |
| ------------------------- | ----------------------------- | ------------------------------------------------- | ----------------------- |
| Cámara                    | camera                        | Capturar el recibo en el momento de la compra     | RF-14, RNF-12           |
| Galería                   | image_picker                  | Usar una foto del recibo tomada antes             | RF-14                   |
| OCR en el dispositivo     | google_mlkit_text_recognition | Extraer el valor y el comercio sin escribirlos    | RF-15, RF-16, RNF-13    |
| Notificaciones locales    | flutter_local_notifications   | Avisar antes de pasarse del presupuesto           | RF-32                   |
| Almacenamiento interno    | path_provider + Drift         | Guardar datos e imágenes disponibles sin conexión | RF-24, RNF-09           |
| Almacenamiento seguro     | flutter_secure_storage        | Proteger tokens y la clave de cifrado             | RNF-04, RNF-05          |
| Biometría y PIN           | local_auth                    | Desbloquear rápido sin exponer los datos          | RF-12, RNF-08           |
| Detección de conectividad | connectivity_plus             | Sincronizar automáticamente al volver la conexión | RF-25, RNF-10           |

## 7.1 Cámara: captura del recibo

La cámara es la puerta de entrada de la funcionalidad principal de MisLukas. Cuando el usuario elige "Foto del recibo" y toca "Continuar", la aplicación abre una vista de cámara propia, integrada en la app, en lugar de enviar al usuario a la aplicación de cámara del sistema.

**Por qué una cámara integrada.** Abrir la cámara del sistema implica salir de MisLukas, tomar la foto, confirmarla y volver, con pasos adicionales que alargan el registro. Una vista integrada permite guiar al usuario y mantener el flujo dentro de la aplicación, lo que es clave para cumplir la meta de registrar un gasto en menos de 15 segundos (RNF-12).

**Cómo funciona.**

- **Guía de encuadre.** La vista muestra un marco con esquinas resaltadas y el texto "Ubica el recibo dentro del marco", que ayuda a obtener una imagen más legible.
- **Controles.** Incluye un botón de linterna para lugares con poca luz, habituales en el momento de pagar, y un acceso rápido a la galería.
- **Revisión.** Después de la captura se muestra la foto durante un instante con las opciones "Usar foto" y "Repetir", para descartar imágenes borrosas antes de procesarlas.
- **Optimización.** La imagen se redimensiona y comprime antes de pasar al OCR. Una resolución más baja sigue siendo suficiente para leer el texto y reduce el tiempo de procesamiento y el espacio ocupado.

**Manejo de la imagen.** La foto se guarda en el directorio privado de la aplicación, al que otras aplicaciones no tienen acceso. **No se guarda en la galería del usuario**, para no mezclar recibos con sus fotos personales ni exponerlos a aplicaciones que tengan acceso a la galería. Si el usuario cancela el registro, la imagen temporal se elimina.

## 7.2 Galería: subir una foto existente

No siempre es posible fotografiar el recibo en el momento. Muchas personas toman la foto rápido para registrarla después, o reciben el recibo como imagen por correo o por un chat. Para esos casos, desde la vista de cámara se puede abrir la galería y seleccionar una imagen.

**Uso del selector del sistema.** La selección se hace con el selector de fotos que ofrece el propio sistema operativo, mediante image_picker. Con este mecanismo, la aplicación solo recibe la imagen que el usuario eligió, no acceso a toda su galería. En las versiones actuales de Android e iOS, esto permite seleccionar la foto sin conceder un permiso amplio sobre la biblioteca de imágenes. Es la opción más respetuosa con la privacidad: MisLukas no necesita ver las fotos del usuario, solo la del recibo.

Una vez seleccionada, la imagen sigue exactamente el mismo proceso que una foto tomada con la cámara: se copia al directorio privado de la aplicación, se optimiza y pasa al reconocimiento de texto.

## 7.3 OCR en el dispositivo: extracción del valor y el comercio

El reconocimiento óptico de caracteres (OCR) convierte la imagen del recibo en texto que la aplicación puede interpretar. MisLukas utiliza el reconocimiento de texto de Google ML Kit, que **se ejecuta completamente en el dispositivo** con un modelo incluido en la aplicación.

**Por qué en el dispositivo y no en la nube.** Existen servicios de OCR en la nube con mayor precisión en algunos casos, pero descartamos esa opción por tres razones:

- Requieren conexión, lo que contradice el enfoque offline-first.
- Implican enviar la foto del recibo a un servidor externo, con el riesgo de privacidad que eso supone.
- Dependen de la velocidad de la red, lo que haría variable el tiempo de lectura.

Con el procesamiento local, la lectura funciona en cualquier lugar, la imagen no sale del celular y el tiempo de respuesta es predecible (RNF-13).

**Proceso de extracción.** ML Kit entrega el texto del recibo organizado en bloques y líneas. A partir de ahí, la aplicación aplica su propia lógica de interpretación, implementada como un caso de uso de la capa de dominio:

1. **Detección del total.** Se buscan las líneas que contienen palabras clave como "TOTAL", "TOTAL A PAGAR", "VALOR TOTAL" o "NETO". En la misma línea o en la siguiente se busca un valor numérico. Si hay varias coincidencias, se da prioridad a la que aparece más abajo en el recibo, porque en la mayoría de formatos el total final va al pie, después de subtotales e impuestos.
2. **Normalización del valor.** Los recibos colombianos escriben los montos de formas distintas: "\$87.400", "87,400", "87400" o "87.400,00". La aplicación reconoce estos formatos y los convierte a un número entero de pesos. Si no se encuentra una palabra clave, se propone el valor más alto del recibo como candidato, siempre para que el usuario lo confirme.
3. **Detección del comercio.** Se toma el texto de las primeras líneas del recibo, donde suele ir el nombre del establecimiento, y se compara con un diccionario local de comercios frecuentes en Colombia (supermercados, cadenas de restaurantes y cafés, estaciones de servicio, droguerías, sistemas de transporte, entre otros).
4. **Sugerencia de categoría.** Si el comercio está en el diccionario, se sugiere la categoría asociada: un supermercado sugiere Mercado y una cadena de cafés sugiere Ocio. Si no se reconoce, se revisan palabras del propio texto ("supermercado", "droguería", "restaurante") y, si aún no hay coincidencia, no se preselecciona ninguna categoría.
5. **Resultado para el usuario.** La pantalla "Confirma los datos" muestra el valor, la categoría sugerida y la imagen con el área del total resaltada. El usuario siempre puede corregir antes de guardar (RF-17).

**Por qué reglas y no inteligencia artificial para la categoría.** Para el MVP, un diccionario de comercios y palabras clave es suficiente, transparente y funciona sin conexión. Un modelo de clasificación entrenado podría mejorar la precisión, pero requiere datos de entrenamiento que el proyecto aún no tiene. A futuro, la sugerencia podría aprender de las correcciones del usuario: si siempre cambia un comercio de Otros a Restaurantes, la próxima vez se sugiere Restaurantes.

**Limitaciones conocidas.** La calidad de la lectura depende de la imagen. Los recibos arrugados, los de papel térmico desteñido, los escritos a mano y las fotos con poca luz o movidas pueden producir lecturas incorrectas o incompletas. La aplicación contempla estos casos de tres formas:

- La guía de encuadre y la linterna mejoran la captura.
- El valor siempre es editable.
- Si no se detecta ningún valor, se informa al usuario y se le permite ingresarlo manualmente (RF-18).

La función está pensada para ahorrar trabajo en la mayoría de los casos, no para ser infalible, y el diseño asume que el usuario tiene la última palabra.

## 7.4 Notificaciones locales: alertas de presupuesto

Las alertas de presupuesto son más útiles si llegan en el momento preciso, aunque el usuario no esté mirando la pantalla de inicio. Para eso, MisLukas usa notificaciones del sistema.

**Por qué locales y no push.** Las notificaciones push se envían desde un servidor, lo que requeriría que el servidor calcule los presupuestos de cada usuario y que el dispositivo tenga conexión para recibirlas. En MisLukas, el cálculo del presupuesto ya ocurre en el dispositivo cada vez que se guarda un movimiento. Por eso la notificación se genera ahí mismo: funciona sin conexión, llega de inmediato y no requiere infraestructura adicional en el servidor.

**Cuando se generan.** Después de guardar un gasto, el caso de uso EvaluarAlertasDePresupuesto calcula el porcentaje usado del presupuesto de esa categoría. Si el gasto cruza un umbral, se genera la alerta:

| Umbral               | Mensaje de ejemplo                                                                 |
| -------------------- | ---------------------------------------------------------------------------------- |
| 75% del presupuesto  | "Llevas el 78% de tu presupuesto de mercado. Te quedan \$253.000 para fin de mes." |
| 100% del presupuesto | "Superaste tu presupuesto de ocio de septiembre."                                  |

**Evitar el exceso de notificaciones.** Una aplicación que notifica demasiado termina silenciada o desinstalada. Por eso cada alerta se envía **una sola vez por categoría, por umbral y por mes**. Si Camila ya recibió la alerta del 75% en mercado, no la volverá a recibir con cada compra; la siguiente será la del 100%, si llega a ocurrir. Además, las alertas pueden desactivarse desde el perfil, y el texto de la notificación está pensado para ser útil incluso si el usuario no abre la aplicación.

**Privacidad en la pantalla de bloqueo.** Las notificaciones pueden aparecer con el celular bloqueado y a la vista de otras personas. Por eso se configuran como contenido privado: la vista en la pantalla de bloqueo muestra un texto general ("Tienes una alerta de presupuesto") y el detalle con los montos solo se ve al desbloquear el dispositivo.

## 7.5 Almacenamiento interno: base cifrada e imágenes

Cada aplicación móvil tiene un espacio de almacenamiento privado dentro del dispositivo, aislado de las demás aplicaciones por el propio sistema operativo. MisLukas guarda en ese espacio:

- **La base de datos SQLite**, cifrada con SQLCipher, con los movimientos, categorías, presupuestos, datos de recibos y la cola de sincronización (sección 6.5).
- **Las imágenes de los recibos**, en una carpeta propia de la aplicación.
- **Las preferencias no sensibles**, como la última pestaña visitada.

**Protección frente a copias de seguridad.** Los sistemas operativos pueden incluir los datos de las aplicaciones en las copias de seguridad automáticas del dispositivo. Para evitar que la base de datos y las imágenes de los recibos terminen en una copia fuera del control de la aplicación, se excluyen de las copias de seguridad del sistema. Esto no implica pérdida de información para el usuario, porque sus datos ya se respaldan en Supabase mediante la sincronización. Aun si el archivo de la base llegara a copiarse, sin la clave de cifrado sería ilegible.

**Espacio ocupado.** Los datos estructurados ocupan muy poco espacio: miles de movimientos caben en unos pocos megabytes. Las imágenes son lo que más crece, por eso se comprimen al guardarse. En una versión futura se podrá configurar que las imágenes de recibos con más de cierto tiempo se eliminen del dispositivo, conservando los datos del movimiento.

**Al cerrar sesión o eliminar la cuenta**, la aplicación borra la base de datos local, las imágenes y la clave de cifrado, de modo que no quede información financiera en el dispositivo (RF-13, RF-48).

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

7.9.3 Funcionalidades que no requieren permisos

Varias de las funcionalidades descritas no requieren ningún permiso del usuario, porque operan dentro del espacio propio de la aplicación:

**OCR:** procesa imágenes que la aplicación ya tiene.

**Almacenamiento interno:** es el espacio privado de la app.

**Keystore y Keychain:** se asignan automáticamente a cada aplicación.

**Notificaciones programadas por la propia app:** solo requieren el permiso general de notificaciones.

Esto también forma parte del diseño: cuantas menos capacidades sensibles solicita una aplicación, menor es su superficie de riesgo y mayor es la confianza del usuario.
