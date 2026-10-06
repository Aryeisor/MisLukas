# 8. Seguridad y privacidad

MisLukas almacena información que revela mucho de una persona: cuánto gana, en qué gasta, dónde compra y con qué frecuencia. Si esa información se filtra, el daño no es solo técnico. Puede facilitar fraudes, extorsiones o simplemente exponer la intimidad del usuario. Por eso la seguridad no se trata en este proyecto como una capa que se agrega al final, sino como un criterio que atraviesa todas las decisiones descritas en las secciones anteriores.

Esta sección reúne esas decisiones y las organiza en tres frentes:

**Controlar quién entra:** autenticación en el inicio de sesión, el registro y la recuperación de contraseña.

**Controlar a qué accede cada quien:** autorización e inyección SQL.

**Proteger los datos donde están:** en tránsito por la red y guardados en el dispositivo.

Cierra con las obligaciones legales de privacidad y con las mejoras previstas para versiones futuras.

## 8.1 Marco de referencia y modelo de amenazas

8.1.1 Marco de referencia

Para no depender solo del criterio del equipo, la seguridad de MisLukas se alinea con estándares reconocidos de la Fundación OWASP (_Open Worldwide Application Security Project_):

**OWASP Mobile Top 10 (edición 2024):** lista de los diez riesgos más críticos en aplicaciones móviles. Se usa como lista de verificación para confirmar que cada riesgo tiene al menos un control en el diseño.

**OWASP MASVS** (_Mobile Application Security Verification Standard_): estándar de requisitos de seguridad específico para aplicaciones móviles, organizado en áreas como almacenamiento, criptografía, autenticación, red, plataforma, código y privacidad.

**OWASP ASVS** (_Application Security Verification Standard_): estándar para la parte del servidor, aplicado a la configuración de Supabase, las políticas de acceso y las funciones de base de datos.

La siguiente tabla relaciona cada riesgo del OWASP Mobile Top 10 con los controles de MisLukas y la sección donde se desarrollan:

| Riesgo OWASP Mobile Top 10 (2024)                   | Control en MisLukas                                                                         | Sección     |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------- | ----------- |
| M1. Uso inadecuado de credenciales                  | Sin credenciales ni claves secretas en el código; tokens solo en almacenamiento seguro      | 8.2, 8.5    |
| M2. Seguridad inadecuada de la cadena de suministro | Dependencias oficiales, versiones fijadas y revisión periódica                              | 8.8.5       |
| M3. Autenticación y autorización inseguras          | Supabase Auth, límites de intentos, RLS en todas las tablas                                 | 8.2 a 8.5   |
| M4. Validación insuficiente de entradas y salidas   | Validación en cliente y servidor, consultas parametrizadas                                  | 8.6         |
| M5. Comunicación insegura                           | HTTPS/TLS obligatorio                                                                       | 8.7         |
| M6. Controles de privacidad inadecuados             | Minimización de datos, consentimiento, eliminación de cuenta                                | 8.9         |
| M7. Protección insuficiente del binario             | Ofuscación del código compilado; detección de root/jailbreak a futuro                       | 8.8.5, 8.11 |
| M8. Configuración de seguridad incorrecta           | Exclusión de copias de seguridad, entornos separados, revisión de configuración de Supabase | 8.8, 9.4    |
| M9. Almacenamiento de datos inseguro                | Base local cifrada, Keystore/Keychain, borrado al cerrar sesión                             | 8.8         |
| M10. Criptografía insuficiente                      | SQLCipher con clave de 256 bits, hash de contraseñas y PIN                                  | 8.2, 8.8    |

8.1.2 Activos a proteger

| Activo                                                  | Dónde está                                       | Impacto si se compromete                                             |
| ------------------------------------------------------- | ------------------------------------------------ | -------------------------------------------------------------------- |
| Datos financieros (movimientos, ingresos, presupuestos) | Base local y PostgreSQL                          | Alto: exposición de la situación económica y los hábitos del usuario |
| Credenciales (contraseña)                               | Solo en el servidor, como hash                   | Crítico: acceso total a la cuenta                                    |
| Tokens de sesión                                        | Keystore/Keychain                                | Crítico: suplantación del usuario sin conocer la contraseña          |
| Clave de cifrado local                                  | Keystore/Keychain                                | Alto: permitiría leer la base del dispositivo                        |
| Fotos de recibos                                        | Almacenamiento interno y, opcionalmente, Storage | Medio-alto: revelan lugares, horarios y medios de pago               |
| Datos de identificación (nombre y correo)               | Supabase Auth y tabla perfiles                   | Medio: permiten phishing dirigido al usuario                         |

8.1.3 Amenazas consideradas

**Robo o pérdida del celular.** Es la amenaza más probable para una aplicación móvil. Quien tenga el dispositivo podría intentar abrir la aplicación o extraer sus archivos.  
_Controles:_ desbloqueo biométrico o PIN, bloqueo automático, base de datos cifrada y tokens en almacenamiento seguro (8.8).

**Ataques de fuerza bruta y relleno de credenciales.** Consisten en probar muchas contraseñas contra una cuenta, o probar combinaciones de correo y contraseña filtradas de otros sitios (_credential stuffing_), aprovechando que muchas personas reutilizan sus contraseñas.  
_Controles:_ límites de intentos por IP y por cuenta, CAPTCHA y política de contraseñas (8.2).

**Interceptación de la comunicación.** Un atacante en la misma red, por ejemplo un wifi público, podría intentar leer o modificar el tráfico entre la app y el servidor.  
_Controles:_ HTTPS/TLS obligatorio (8.7).

**Suplantación de identidad.** Alguien podría intentar hacerse pasar por el usuario robando su sesión, abusando del flujo de recuperación de contraseña o engañándolo con un correo falso.  
_Controles:_ tokens de corta duración, códigos de recuperación de un solo uso, cierre de sesiones tras el cambio de contraseña y notificaciones de seguridad (8.2, 8.4).

**Acceso a datos de otros usuarios.** Un usuario legítimo podría modificar las solicitudes que envía la app para intentar leer los movimientos de otra persona.  
_Controles:_ Row Level Security en la base de datos (8.5).

**Inyección de código.** Un atacante podría intentar introducir instrucciones SQL en un campo de texto para manipular la base de datos.  
_Controles:_ consultas parametrizadas y validación de entradas (8.6).

**Enumeración de usuarios.** A partir de las respuestas del sistema, alguien podría averiguar qué correos tienen cuenta en MisLukas y usarlos para ataques dirigidos.  
_Controles:_ mensajes genéricos en el inicio de sesión y la recuperación (8.2, 8.4).

## 8.2 Autenticación: inicio de sesión

El inicio de sesión es el punto más expuesto de la aplicación: es público, cualquiera puede intentarlo y detrás está toda la información del usuario. Por eso concentra la mayor cantidad de controles.

8.2.1 Limitación de intentos (rate limiting)

La limitación de intentos se aplica en dos niveles, porque cada uno detiene un tipo de ataque distinto.

**Nivel 1: por dirección IP.** Supabase Auth aplica límites de solicitudes a sus servicios de autenticación para prevenir abusos. Algunos de ellos se pueden configurar desde el panel del proyecto. Funciona con un algoritmo de _token bucket_: tolera ráfagas cortas de actividad legítima, pero rechaza el tráfico sostenido por encima del límite con un error 429 (_Too Many Requests_). Por defecto, el servicio que procesa los inicios de sesión permite 150 solicitudes cada 5 minutos por IP, y los de registro y recuperación, 30 solicitudes cada 5 minutos. Para MisLukas, el límite del inicio de sesión se reducirá, ya que un usuario real no necesita más que unos pocos intentos.  
_Este nivel frena a un atacante que prueba muchas contraseñas desde un mismo origen._

**Nivel 2: por cuenta.** El límite por IP no detiene a un atacante que reparte sus intentos entre muchas direcciones distintas. Para cubrir ese caso, se usa el _Password Verification Hook_ de Supabase Auth, una función que se ejecuta en cada intento de inicio de sesión con contraseña y recibe si la contraseña fue válida o no. Con ella, la función puede registrar los intentos fallidos y rechazar los siguientes cuando se superan los límites.

Las reglas se implementan como una función de PostgreSQL que guarda los intentos fallidos por usuario en una tabla inaccesible desde la aplicación.

La regla para MisLukas es la definida en RF-07: después de cinco intentos fallidos en quince minutos, la cuenta rechaza nuevos intentos durante quince minutos.

**Bloqueo progresivo y no permanente.** La propia documentación de Supabase advierte que, como este mecanismo se ejecuta sobre solicitudes no autenticadas, puede ser abusado para bloquear a usuarios legítimos, y recomienda preferir las notificaciones al bloqueo cuando sea posible. Es un equilibrio real: si el bloqueo fuera permanente, cualquiera que conozca el correo de Camila podría dejarla sin acceso a propósito. Por eso en MisLukas:

El bloqueo siempre es temporal.

Los tiempos de espera crecen si los intentos continúan.

Al producirse un bloqueo, se envía un correo al usuario para que sepa que alguien intentó entrar a su cuenta y, si no fue él, cambie su contraseña.

La disponibilidad del _hook_ depende del plan del proyecto de Supabase; se verificará al configurar el entorno de producción.

**CAPTCHA.** Supabase Auth permite integrar verificación contra bots con proveedores como hCaptcha y Cloudflare Turnstile. MisLukas lo habilitará en el registro, el inicio de sesión y la recuperación de contraseña, dando preferencia a una modalidad que en la mayoría de los casos no exige interacción del usuario. Así se frenan los ataques automatizados sin añadir fricción para la mayoría de las personas.

**Respaldo en el cliente.** La aplicación también deshabilita el botón de inicio de sesión mientras hay una solicitud en curso y aplica esperas crecientes después de cada fallo. Este control mejora la experiencia, pero **no se considera una medida de seguridad**: un atacante no usa la aplicación, sino que envía solicitudes directamente al servidor. La protección real siempre está en el servidor.

8.2.2 Mensajes de error genéricos

Ante credenciales incorrectas, la aplicación muestra siempre el mismo mensaje: _"Correo o contraseña incorrectos."_ Nunca indica si el correo no existe o si la contraseña es la equivocada. Si el sistema respondiera "este correo no está registrado", un atacante podría usar el formulario para comprobar qué correos tienen cuenta y concentrar sus ataques en ellos (RF-06). El mensaje de bloqueo temporal tampoco revela si la cuenta existe.

8.2.3 Almacenamiento de contraseñas

MisLukas nunca guarda contraseñas. Esta responsabilidad la asume Supabase Auth, que almacena únicamente el _hash_ de cada contraseña calculado con bcrypt, una función diseñada específicamente para este propósito. Cada hash se acompaña de un valor aleatorio (_salt_) generado para cada usuario.

Un hash es una transformación de una sola vía: a partir de él no se puede recuperar la contraseña original, ni siquiera por parte de los administradores del sistema. El _salt_ hace que dos usuarios con la misma contraseña tengan hashes distintos, lo que impide usar tablas de hashes precalculados. Además, bcrypt es deliberadamente lento de calcular, lo que encarece enormemente cualquier intento de adivinar contraseñas a partir de una base de datos robada.

8.2.4 Política de contraseñas

La política se aplica en el cliente, para dar retroalimentación inmediata mientras el usuario escribe, y en el servidor, para que ninguna solicitud pueda saltársela. Supabase Auth permite configurar una longitud mínima y exigir que la contraseña contenga dígitos, minúsculas, mayúsculas y símbolos.

| Regla                 | Valor en MisLukas                                             |
| --------------------- | ------------------------------------------------------------- |
| Longitud mínima       | 8 caracteres (se recomienda al usuario usar 12 o más)         |
| Caracteres requeridos | Al menos un dígito, una minúscula, una mayúscula y un símbolo |
| Contraseñas filtradas | Rechazo de contraseñas conocidas en filtraciones (ver nota)   |
| Cambio de contraseña  | Exige la contraseña actual                                    |

**Nota sobre contraseñas filtradas.** Supabase puede rechazar contraseñas que aparecen en filtraciones públicas, consultando la base de datos _Pwned Passwords_ de HaveIBeenPwned. Esta función está disponible a partir del plan Pro. Para el MVP, se evaluará activarla al pasar a producción. Mientras tanto, la aplicación mantiene una lista local de las contraseñas más comunes para rechazarlas desde el cliente.

Para el cambio de contraseña desde el perfil (RF-45), se activa la opción de Supabase que exige la contraseña actual antes de aceptar una nueva. Así, alguien que encuentre el celular desbloqueado con la app abierta no puede cambiar la contraseña y apropiarse de la cuenta.

8.2.5 Tokens de sesión

Después de un inicio de sesión exitoso, Supabase entrega dos credenciales:

- **Token de acceso (JWT):** acompaña cada solicitud al servidor y le indica a PostgreSQL quién es el usuario. Tiene una **vida corta**, configurada en una hora. Si fuera robado, solo serviría por un tiempo limitado.
- **Token de renovación:** permite obtener un nuevo token de acceso cuando el anterior expira, sin pedir de nuevo la contraseña. Supabase lo **rota en cada uso**: cada renovación entrega un token de renovación nuevo e invalida el anterior, de modo que un token robado y ya usado no sirve para mantener una sesión paralela.

Ambos tokens se guardan **exclusivamente** en el almacenamiento seguro del sistema (Keystore o Keychain), como se describió en las secciones 6.7.1 y 7.6. Nunca se escriben en registros de depuración (_logs_), en la base de datos local ni en almacenamiento clave-valor sin cifrar.

8.2.6 Cierre de sesión por inactividad

MisLukas distingue dos niveles de "cierre":

- **Bloqueo local por inactividad.** Si la app pasa más de cinco minutos en segundo plano, se bloquea y exige biometría o PIN para volver a mostrar información (RNF-08). La sesión con el servidor sigue activa, así que el usuario no tiene que volver a escribir su contraseña.
- **Cierre de sesión completo.** Ocurre cuando el usuario lo solicita, cuando falla cinco veces el PIN, cuando se cambia la contraseña desde otro dispositivo o cuando la sesión se revoca en el servidor. En ese caso se eliminan los tokens, la base local, las imágenes y la clave de cifrado del dispositivo, y para volver a entrar se necesita el correo y la contraseña.

## 8.3 Registro

El registro es la puerta por la que entran todas las cuentas. Si no se controla, puede usarse para crear cuentas falsas de forma masiva, saturar el envío de correos o registrar cuentas con correos de otras personas.

**Validación en el cliente y en el servidor.** La aplicación valida cada campo mientras el usuario escribe: formato del correo, requisitos de la contraseña, coincidencia de la confirmación y aceptación de la política. Esta validación existe para dar una buena experiencia, no para dar seguridad: cualquier persona puede enviar solicitudes directamente a la API sin pasar por la aplicación. Por eso las mismas reglas se aplican en el servidor, donde Supabase Auth rechaza contraseñas débiles y correos inválidos, y las restricciones de la base de datos rechazan datos fuera de rango. **Regla general del proyecto: toda validación en el cliente tiene su equivalente en el servidor.**

**Verificación del correo.** Una cuenta nueva no puede usarse por completo hasta que el usuario confirma su correo mediante el enlace o código que recibe (RF-04). Esto garantiza que el correo le pertenece, lo cual es indispensable porque ese correo será el medio para recuperar la contraseña. También evita que alguien registre cuentas a nombre de terceros.

**Limitación del registro.** El registro está sujeto al límite por IP de Supabase Auth (30 solicitudes cada 5 minutos por defecto, configurable), y cada usuario debe esperar 60 segundos entre solicitudes de reenvío del correo de confirmación. A esto se suma el CAPTCHA descrito en 8.2.1.

**Envío de correos en producción.** El proveedor de correo integrado en Supabase solo permite enviar 2 correos por hora en total. Ese límite es suficiente para pruebas, pero no para una aplicación en uso. Por eso, antes del lanzamiento se configurará un proveedor de correo propio (SMTP) con un dominio verificado. Esto también mejora la confianza del usuario: los correos de verificación y recuperación llegarán desde una dirección de MisLukas, lo que ayuda a distinguirlos de correos de _phishing_ que intenten suplantar a la aplicación.

## 8.4 Recuperación de contraseña

El flujo de recuperación es el segundo punto más crítico, porque permite obtener acceso a una cuenta **sin conocer su contraseña**. Si tiene una falla, un atacante no necesita adivinar nada: le basta con abusar del proceso.

**Respuesta idéntica exista o no el correo.** Al solicitar la recuperación, la aplicación muestra siempre el mismo mensaje: _"Si el correo está registrado, te enviaremos un código de verificación."_ Además, el tiempo de respuesta debe ser similar en ambos casos, para que tampoco pueda deducirse la existencia de la cuenta midiendo cuánto tarda el sistema (RF-09).

**Código de un solo uso con expiración corta.** En lugar del enlace mágico que Supabase envía por defecto, MisLukas usa un **código numérico de seis dígitos** incluido en la plantilla del correo de recuperación, que el usuario escribe en la aplicación. Se prefirió el código al enlace por dos razones:

- Mantiene al usuario dentro de la app, sin depender de abrir enlaces desde el correo.
- Reduce la costumbre de hacer clic en enlaces de correos, que es justamente lo que explotan los ataques de _phishing_.

Las condiciones del código son:

- Sirve una sola vez; se invalida después de usarse.
- Expira a los diez minutos (RF-08).
- Solicitar uno nuevo invalida el anterior.

**Límite de intentos.** Un código de seis dígitos tiene un millón de combinaciones, lo que lo hace seguro solo si no se pueden probar muchas. Por eso:

- Supabase limita las verificaciones a 30 solicitudes cada 5 minutos por IP.
- Cada usuario debe esperar 60 segundos entre solicitudes de recuperación.
- La aplicación, además, invalida el código después de cinco intentos fallidos y obliga a solicitar uno nuevo.

**Acciones después del cambio.** Cuando la contraseña se actualiza:

1. **Se cierran las demás sesiones.** La aplicación cierra la sesión en todos los demás dispositivos (RF-10), usando la opción de cierre de sesión con alcance sobre las demás sesiones que ofrece el cliente de Supabase. Si el cambio se hizo porque alguien más tenía acceso a la cuenta, ese acceso se corta de inmediato.
2. **Se notifica al usuario.** Se envía un correo informando del cambio, con la fecha y la hora. Si el usuario no lo solicitó, sabrá de inmediato que su cuenta está en riesgo y podrá actuar.

## 8.5 Autorización con Row Level Security

La autenticación responde a la pregunta _"¿quién eres?"_; la autorización responde a _"¿qué puedes ver y hacer?"_. En MisLukas, la regla de autorización es sencilla de enunciar: **cada usuario solo puede ver y modificar sus propios datos**. Lo importante es dónde se aplica esa regla.

8.5.1 Por qué la autorización está en la base de datos

La aplicación se comunica con Supabase a través de una API que expone las tablas de PostgreSQL. Esa API es accesible desde internet, y cualquiera con la dirección del proyecto y la clave pública puede enviarle solicitudes. Si la regla "cada usuario ve solo lo suyo" dependiera de que la aplicación agregue un filtro en sus consultas, bastaría con que alguien modificara la app o escribiera sus propias solicitudes para saltársela.

**Row Level Security (RLS)** resuelve esto llevando la regla a la propia base de datos. Con RLS activado, PostgreSQL evalúa una política para **cada fila** antes de devolverla o modificarla, usando la identidad que viene en el token de acceso. No importa cómo se construya la solicitud: si la fila no pertenece al usuario, la base de datos simplemente no la devuelve ni permite modificarla.

8.5.2 Políticas de MisLukas

Todas las tablas del esquema público tienen RLS activado (RNF-06). Se usan políticas separadas por operación, en lugar de una sola política general, porque permiten ajustar cada caso y facilitan la revisión:

```sql
-- Movimientos: cada usuario gestiona solo los suyos
alter table movimientos enable row level security;

create policy "movimientos_select_propios" on movimientos
  for select to authenticated
  using ( (select auth.uid()) = usuario_id );

create policy "movimientos_insert_propios" on movimientos
  for insert to authenticated
  with check ( (select auth.uid()) = usuario_id );

create policy "movimientos_update_propios" on movimientos
  for update to authenticated
  using ( (select auth.uid()) = usuario_id )
  with check ( (select auth.uid()) = usuario_id );

create policy "movimientos_delete_propios" on movimientos
  for delete to authenticated
  using ( (select auth.uid()) = usuario_id );
```

**Cómo leer estas políticas:**

- auth.uid() devuelve el identificador del usuario que viene en el token de acceso. El usuario no puede alterarlo sin invalidar la firma del token.
- using define qué filas existentes puede ver, actualizar o eliminar el usuario.
- with check define qué valores puede escribir. Es lo que impide que alguien inserte un movimiento con el usuario_id de otra persona.
- to authenticated limita la política a usuarios con sesión iniciada. Las solicitudes anónimas no tienen ninguna política que les dé acceso, así que no ven nada.

Las políticas de presupuestos y recibos siguen el mismo patrón. La tabla perfiles usa id en lugar de usuario_id, porque su identificador es el mismo del usuario. La tabla categorias tiene un caso particular: las categorías predeterminadas son visibles para todos, pero nadie puede modificarlas.

```sql
-- Categorías: se leen las predeterminadas y las propias; solo se modifican las propias
create policy "categorias_select" on categorias
  for select to authenticated
  using ( usuario_id is null or (select auth.uid()) = usuario_id );

create policy "categorias_insert_propias" on categorias
  for insert to authenticated
  with check ( (select auth.uid()) = usuario_id );
```

Con estas políticas, las categorías predeterminadas, que tienen usuario_id nulo, no pueden ser modificadas ni eliminadas por ningún usuario.

**Verificación.** Las políticas se prueban con dos cuentas de prueba: con el token del usuario A se intenta leer, modificar y eliminar datos del usuario B, y se verifica que todas las operaciones fallen o no devuelvan resultados. Esta prueba forma parte de la estrategia de pruebas de la sección 9.3.

8.5.3 La clave pública (anon) no da acceso por sí sola

La aplicación incluye la URL del proyecto y la **clave pública** de Supabase, y es inevitable que así sea: cualquier persona que descomprima la aplicación puede encontrarlas. Esto no es un problema de seguridad, siempre que se entienda qué representa esa clave. Solo identifica el proyecto y le da a quien la usa el rol de visitante anónimo. Con RLS activado y sin políticas para ese rol, un visitante anónimo no puede leer ni escribir ningún dato. Para acceder a información se necesita además un token de acceso válido, que solo se obtiene autenticándose.

8.5.4 La clave service_role nunca va en la aplicación

Supabase también ofrece una **clave de servicio** (service_role), pensada para procesos administrativos en servidores de confianza. Esta clave **ignora todas las políticas de RLS**: quien la tenga puede leer, modificar y borrar los datos de todos los usuarios. Por eso, en MisLukas:

- Nunca se incluye en el código de la aplicación, en archivos de configuración del proyecto Flutter ni en el repositorio.
- Solo se usa, si es necesario, dentro de funciones del servidor (_Edge Functions_), donde se lee desde variables de entorno secretas. Un ejemplo es la eliminación completa de la cuenta, que debe borrar el usuario de Supabase Auth.
- El repositorio incluye reglas para excluir archivos de configuración con secretos, y antes de cada versión se revisa que no haya claves en el código.

8.5.5 Políticas equivalentes en Storage

Las fotos de recibos que el usuario decide respaldar se guardan en un _bucket_ **privado** de Supabase Storage, es decir, sin acceso público por URL. Cada archivo se ubica en una carpeta con el identificador del usuario, por ejemplo, recibos/{usuario_id}/{recibo_id}.jpg, y las políticas de Storage, que también funcionan con RLS, verifican que la carpeta coincida con el usuario autenticado:

```sql
create policy "recibos_storage_propios" on storage.objects
  for all to authenticated
  using (
    bucket_id = 'recibos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'recibos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
```

Para mostrar una imagen respaldada, la aplicación solicita una **URL firmada** de corta duración, que deja de funcionar a los pocos minutos. Así, aunque una URL se filtre, no permite acceder a la imagen de forma permanente.

## 8.6 Prevención de inyección SQL

La inyección SQL ocurre cuando un dato ingresado por el usuario se inserta directamente en una consulta y la base de datos lo interpreta como parte de las instrucciones. Por ejemplo, si una consulta se construyera concatenando texto y alguien escribiera en la nota del gasto algo como '; DROP TABLE movimientos; --, la base de datos podría ejecutarlo como una orden. La defensa principal es que **los datos nunca se mezclen con el código de la consulta**, lo que se logra con consultas parametrizadas.

**En el servidor: cliente de Supabase.** La aplicación no escribe consultas SQL para comunicarse con Supabase. Usa los métodos del cliente (.from(), .select(), .eq(), .upsert()), que construyen solicitudes a la API de Supabase. La API traduce esas solicitudes a consultas en las que los valores del usuario viajan siempre como parámetros, nunca como parte del texto de la instrucción. Además, aunque un atacante lograra algún tipo de manipulación, las políticas de RLS seguirían limitando lo que puede alcanzar.

**Funciones SQL propias: el punto de cuidado.** El riesgo de inyección reaparece si el equipo escribe funciones de PostgreSQL que construyen consultas dinámicamente, por ejemplo con EXECUTE y concatenación de texto. Para evitarlo:

- Se evita el SQL dinámico siempre que sea posible.
- Cuando sea imprescindible, se usa format() con los marcadores %I para nombres de tablas y columnas y %L para valores, o EXECUTE ... USING para pasar los valores como parámetros. Nunca se concatenan valores con ||.
- Las funciones que no necesitan permisos especiales se declaran con SECURITY INVOKER, para que se ejecuten con los permisos del usuario y respeten RLS.
- Las funciones que sí requieren SECURITY DEFINER fijan explícitamente su search_path y validan dentro de la función que el usuario solo opere sobre sus propios datos.

```sql
-- Incorrecto: el valor se concatena al texto de la consulta
execute 'select * from movimientos where nota = ''' || p_nota || '''';

-- Correcto: el valor viaja como parámetro
execute 'select * from movimientos where nota = $1' using p_nota;
```

**En el dispositivo: Drift.** Las consultas a la base local también son parametrizadas. Drift genera el código de acceso a datos a partir de la definición de las tablas y siempre pasa los valores como parámetros a SQLite. En el proyecto no se permite construir consultas con interpolación de texto ('... \$variable ...') en llamadas de SQL directo; esta regla se revisa en las revisiones de código.

**Validación y sanitización de entradas.** Las consultas parametrizadas evitan la inyección, pero no garantizan que los datos sean válidos. Por eso cada entrada se valida según su tipo y su origen:

| Entrada                 | Origen                | Validación                                                                                                                                                            |
| ----------------------- | --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Monto                   | Usuario u OCR         | Solo dígitos tras normalizar el formato; entero mayor que cero y menor que un tope razonable. Restricción CHECK (monto > 0) en la base de datos.                      |
| Texto detectado por OCR | Imagen del recibo     | Se trata como dato no confiable: se extraen solo el número del total y el nombre del comercio, se recortan espacios y caracteres de control, y se limita la longitud. |
| Nota y descripción      | Usuario               | Longitud máxima (por ejemplo, 200 caracteres), eliminación de caracteres de control. Se muestran siempre como texto, nunca se interpretan.                            |
| Categoría               | Selección del usuario | Debe corresponder a una categoría existente y visible para el usuario; lo garantiza una llave foránea.                                                                |
| Tipo y origen           | Aplicación            | Solo valores permitidos ("gasto" o "ingreso"; "foto" o "manual"), con restricciones CHECK.                                                                            |
| Fecha                   | Usuario               | Formato válido; no se aceptan fechas futuras lejanas.                                                                                                                 |
| Correo y nombre         | Registro              | Formato de correo válido; longitud máxima del nombre.                                                                                                                 |

El texto del OCR merece una mención especial: aunque proviene de una foto, su contenido lo controla quien imprimió el recibo. Tratarlo como cualquier otra entrada externa, validarlo y limitarlo es una práctica de defensa en profundidad.

## 8.7 Seguridad de la comunicación

**HTTPS/TLS obligatorio.** Toda comunicación entre la aplicación y Supabase se realiza sobre HTTPS con TLS, que cifra los datos en tránsito y verifica la identidad del servidor mediante su certificado (RNF-03). Supabase solo expone sus servicios por HTTPS, y la aplicación se configura para rechazar conexiones sin cifrar:

- **En Android**, la configuración de seguridad de red de la aplicación prohíbe el tráfico en texto plano.
- **En iOS**, se mantiene activa la política de seguridad de transporte (ATS) del sistema, sin excepciones.

Con esto, aunque Camila use el wifi público de un centro comercial, quien esté en esa red no puede leer ni modificar lo que la app envía y recibe.

**Certificate pinning como mejora futura.** TLS confía en cualquier certificado emitido por una autoridad reconocida por el sistema operativo. El _certificate pinning_ va un paso más allá: la aplicación solo acepta el certificado específico del servidor o de su emisor, lo que protege incluso si un atacante logra instalar un certificado falso en el dispositivo. No se incluye en el MVP porque, si los certificados del servidor cambian y la aplicación no se actualiza a tiempo, todos los usuarios quedarían sin conexión. Implementarlo bien requiere un procedimiento de rotación de certificados que se definirá cuando la aplicación esté en producción (8.11).

## 8.8 Protección de datos en el dispositivo

El celular es el lugar donde más tiempo pasan los datos de MisLukas y también el más expuesto: se pierde, se presta, se roba o se conecta a computadores. La protección en el dispositivo parte de una premisa: **si alguien obtiene el celular, no debe poder obtener la información financiera del usuario.**

8.8.1 Base de datos local cifrada

Como se explicó en 6.5 y 7.5:

- Toda la base de datos local se cifra con SQLCipher usando una clave aleatoria de 256 bits, generada en el dispositivo y guardada en el Keystore o el Keychain.
- El archivo y las imágenes de recibos se excluyen de las copias de seguridad del sistema.
- Si alguien extrae el archivo de la base, obtiene datos ilegibles. Para leerlos necesitaría la clave, y el sistema operativo solo se la entrega a MisLukas.

8.8.2 Bloqueo biométrico o PIN

El acceso a la información requiere biometría o el PIN de la aplicación cada vez que se abre y después de cinco minutos en segundo plano (7.7):

- El PIN se guarda como hash con _salt_ en el almacenamiento seguro, nunca en texto plano.
- Después de cinco intentos fallidos, la aplicación cierra la sesión completa y exige correo y contraseña, lo que traslada el control al servidor y a sus límites de intentos.

8.8.3 Ocultar información en la vista de aplicaciones recientes

Cuando el usuario cambia de aplicación, el sistema guarda una captura de la pantalla para mostrarla en el selector de aplicaciones recientes. Sin protección, esa captura podría mostrar el disponible del mes o los últimos movimientos a cualquiera que mire el celular. MisLukas lo evita así:

- **En Android**, se marca la ventana de la aplicación como segura (FLAG_SECURE). El sistema muestra una vista en blanco en recientes y además impide las capturas y grabaciones de pantalla.
- **En iOS**, al pasar a segundo plano se superpone una vista con el logo de la aplicación sobre el contenido, de modo que la captura del sistema no muestre información.

Bloquear las capturas de pantalla tiene un costo: el usuario tampoco puede capturar sus reportes para compartirlos. Por eso la protección se aplica a las pantallas con información financiera, y en una versión futura se ofrecerá la exportación de reportes (4.2) como alternativa controlada.

8.8.4 Borrado de datos locales

Al cerrar sesión, al eliminar la cuenta o al superar los intentos fallidos del PIN, la aplicación elimina del dispositivo:

- La base de datos local.
- Las imágenes de recibos.
- La clave de cifrado.
- Los tokens de sesión.
- El hash del PIN.

Si hay cambios pendientes de sincronizar, antes de cerrar sesión se intenta enviarlos. Si no hay conexión, se advierte al usuario que esos cambios se perderán y se le pide confirmar. Se eligió esta advertencia, en lugar de conservar los datos, porque dejar información financiera en un dispositivo sin sesión sería un riesgo mayor.

8.8.5 Protección del código y de las dependencias

**Ofuscación.** La versión de publicación se compila con ofuscación del código Dart (flutter build --obfuscate --split-debug-info), lo que dificulta analizar la aplicación mediante ingeniería inversa. La ofuscación no reemplaza a los demás controles, porque ningún secreto debe depender de que el código sea difícil de leer, pero eleva el esfuerzo necesario para un atacante.

**Registros de depuración.** En la versión de publicación no se escriben en los registros del sistema tokens, montos, correos, contenidos de recibos ni ningún otro dato personal.

**Dependencias.** Solo se usan paquetes oficiales o ampliamente mantenidos de pub.dev. Las versiones se fijan en el archivo de bloqueo del proyecto y se revisan periódicamente para aplicar actualizaciones de seguridad, lo que responde al riesgo M2 de la cadena de suministro.

## 8.9 Privacidad y cumplimiento legal

8.9.1 Ley 1581 de 2012

La Ley 1581 de 2012 es el régimen general de protección de datos personales en Colombia, reglamentado principalmente por el Decreto 1377 de 2013, hoy compilado en el Decreto 1074 de 2015. Como MisLukas recolecta datos personales de personas en Colombia, el responsable del tratamiento debe cumplirla. La autoridad de vigilancia es la Superintendencia de Industria y Comercio (SIC).

**Naturaleza de los datos que se tratan.** Es importante precisar qué datos maneja MisLukas desde el punto de vista legal:

- **Nombre y correo:** datos personales de identificación.
- **Movimientos, ingresos, presupuestos y recibos:** datos personales sobre la situación económica del usuario. La ley no los clasifica como "datos sensibles" en su definición legal, pero por el daño que causaría su exposición se tratan con el mismo nivel de protección.
- **Datos biométricos:** la ley sí los considera sensibles. **MisLukas no los recolecta ni los procesa**: la verificación de huella y rostro la hace el sistema operativo, y la aplicación solo recibe una respuesta de éxito o fallo (7.7).

Principios aplicados

| Principio                        | Cómo se aplica en MisLukas                                                                                                                                                                                 |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Legalidad                        | El tratamiento se ajusta a la Ley 1581 y sus decretos reglamentarios.                                                                                                                                      |
| Finalidad                        | Los datos se usan solo para prestar el servicio: registrar, analizar y proyectar las finanzas del usuario. No se venden, no se usan para publicidad y no se comparten con terceros para fines comerciales. |
| Libertad                         | El tratamiento solo ocurre con autorización previa, expresa e informada del usuario.                                                                                                                       |
| Veracidad o calidad              | El usuario puede corregir y actualizar sus datos en cualquier momento.                                                                                                                                     |
| Transparencia                    | La política de tratamiento está disponible antes del registro y dentro de la aplicación.                                                                                                                   |
| Acceso y circulación restringida | Row Level Security garantiza que solo el titular accede a sus datos.                                                                                                                                       |
| Seguridad                        | Las medidas técnicas de esta sección.                                                                                                                                                                      |
| Confidencialidad                 | El equipo con acceso a la infraestructura se compromete a no divulgar la información.                                                                                                                      |

**Autorización del titular.** La ley exige que la autorización sea previa, expresa e informada. En MisLukas:

- **Previa y expresa:** la casilla de aceptación del registro es obligatoria y no viene marcada por defecto (RF-03).
- **Informada:** el texto enlaza a la política de tratamiento completa.
- **Demostrable:** el responsable debe poder probar que obtuvo la autorización. Por eso la tabla perfiles registrará la **versión de la política aceptada y la fecha de aceptación**, y si la política cambia de forma sustancial, se pedirá una nueva aceptación.

**Política de tratamiento de datos.** Se redactará y publicará un documento que incluya, como mínimo:

- Identificación del responsable y datos de contacto.
- Tratamiento al que se someten los datos y su finalidad.
- Derechos del titular.
- Canal y procedimiento para ejercerlos.
- Fecha de entrada en vigencia.

La política estará disponible en la pantalla de registro, en el perfil (RF-49) y en la ficha de la aplicación en las tiendas.

**Derechos del titular y cómo se ejercen en la app.**

| Derecho                                          | Mecanismo en MisLukas                                                                                               |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------- |
| Conocer, actualizar y rectificar sus datos       | Todos los datos son visibles y editables desde la aplicación: movimientos, presupuestos, nombre.                    |
| Solicitar prueba de la autorización              | Registro de versión y fecha de aceptación, disponible a solicitud.                                                  |
| Ser informado sobre el uso de sus datos          | Política de tratamiento en la app.                                                                                  |
| Presentar quejas ante la SIC                     | Informado en la política.                                                                                           |
| Revocar la autorización y solicitar la supresión | Eliminación de cuenta desde la aplicación (8.9.4).                                                                  |
| Acceder gratuitamente a sus datos                | La aplicación es gratuita y el usuario ve toda su información. La exportación de datos se contempla a futuro (4.2). |

Para consultas y reclamos que no se resuelvan desde la aplicación, se habilitará un correo de contacto, respetando los plazos de respuesta que establece la ley: diez días hábiles para consultas y quince días hábiles para reclamos.

**Transferencia internacional.** Los servidores de Supabase pueden ubicarse fuera de Colombia. Para MisLukas se elegirá la región disponible más cercana, por ejemplo São Paulo, lo que además reduce la latencia. Como esto implica que los datos se almacenan en otro país, la política de tratamiento lo informará de forma explícita y, antes de un lanzamiento comercial, se revisarán las condiciones que la ley y la SIC establecen para la transmisión y transferencia internacional de datos.

8.9.2 Minimización de datos

El dato más seguro es el que nunca se recolecta. MisLukas solo pide lo estrictamente necesario:

| Se solicita                | Para qué                     | No se solicita                            |
| -------------------------- | ---------------------------- | ----------------------------------------- |
| Nombre                     | Personalizar el saludo       | Documento de identidad                    |
| Correo                     | Autenticación y recuperación | Teléfono                                  |
| Movimientos y presupuestos | Funcionalidad principal      | Fecha de nacimiento, dirección            |
| Foto del recibo (opcional) | Extraer el valor             | Ubicación del dispositivo                 |
|                            |                              | Credenciales bancarias o acceso a cuentas |
|                            |                              | Contactos, micrófono, galería completa    |

Esta decisión también es de seguridad: si el servidor sufriera una filtración, el daño se limitaría a lo que realmente se guarda.

8.9.3 Manejo de las fotos de recibos

Las fotos de recibos requieren un manejo particular, porque contienen más información de la que la aplicación necesita: dirección del establecimiento, fecha y hora exacta de la compra y, a veces, los últimos dígitos de la tarjeta.

- **Procesamiento local:** el OCR se ejecuta en el dispositivo; la imagen no se envía a ningún servicio externo para su lectura (7.3).
- **Almacenamiento privado:** se guarda en el almacenamiento interno de la app, no en la galería del usuario.
- **Respaldo opcional:** solo se sube a la nube si el usuario activa el respaldo, y en ese caso a un _bucket_ privado con acceso restringido por usuario y URLs firmadas temporales (8.5.5).
- **Datos extraídos mínimos:** de todo el texto del recibo, solo se guardan el total y el nombre del comercio. El resto del texto reconocido se descarta.
- **Eliminación:** el usuario puede eliminar la foto de un recibo sin eliminar el movimiento. Al eliminar la cuenta, se borran todas.

8.9.4 Eliminación de cuenta desde la aplicación

Las dos tiendas de aplicaciones exigen que, si una aplicación permite crear cuentas, también permita eliminarlas:

- **App Store:** las pautas de revisión de Apple lo exigen de forma explícita desde la propia aplicación.
- **Google Play:** exige que las apps que permiten crear cuentas ofrezcan la eliminación dentro de la app y también mediante un enlace web, para usuarios que ya no tengan la aplicación instalada.

Además de ser un requisito de publicación, es la forma de cumplir el derecho de supresión de la Ley 1581.

**Proceso de eliminación en MisLukas (RF-48):**

1. El usuario toca "Eliminar mi cuenta" en el perfil y confirma en un diálogo que explica que la acción es permanente. Por seguridad, se le pide su contraseña.
2. La aplicación llama a una función del servidor (_Edge Function_) que, con la clave de servicio guardada de forma segura en el servidor, elimina:
   - Los archivos del usuario en Storage.
   - Sus registros en las tablas.
   - Su usuario en Supabase Auth.
3. La aplicación borra todos los datos locales (8.8.4) y regresa a la pantalla de inicio de sesión.
4. Se envía un correo confirmando la eliminación.

Los datos se eliminan efectivamente, no solo se marcan como eliminados. A diferencia del borrado lógico usado para sincronizar movimientos individuales (6.4.1), la eliminación de la cuenta es definitiva.

## 8.10 Inicio de sesión con Google y Apple (futuro)

El inicio de sesión con proveedores externos está fuera del MVP (4.2), pero la arquitectura ya lo contempla. Esta sección define cómo se implementará para que, cuando llegue el momento, no se improvise en un tema de seguridad.

**Protocolo: OAuth 2.0 / OpenID Connect con PKCE.** El inicio de sesión con Google o Apple se hará mediante Supabase Auth, que implementa estos estándares. En este esquema, el usuario se autentica directamente con Google o Apple, y **MisLukas nunca ve ni recibe la contraseña de esas cuentas**. La aplicación solo recibe un token firmado que confirma la identidad del usuario, y Supabase lo verifica antes de crear la sesión.

Para aplicaciones móviles se usa la extensión **PKCE** (_Proof Key for Code Exchange_). Antes de iniciar el flujo, la aplicación genera un secreto aleatorio que solo ella conoce, y al final del proceso debe presentarlo para obtener la sesión. Así, si otra aplicación maliciosa en el mismo dispositivo intercepta la respuesta del proveedor, no puede usarla sin ese secreto. Cuando sea posible, se preferirá el inicio de sesión nativo de cada plataforma (el selector de cuentas de Google en Android y "Iniciar sesión con Apple" en iOS), que ofrece mejor experiencia y seguridad que abrir un navegador.

**Vinculación de cuentas con el mismo correo.** Un caso que debe resolverse con cuidado es el de Camila, que se registró con correo y contraseña y luego intenta entrar con Google usando el mismo correo. Supabase permite vincular varias identidades a un mismo usuario. En MisLukas, la vinculación solo se hará cuando el correo esté **verificado en ambos lados**. Sin esta condición, alguien podría crear una cuenta con el correo de otra persona en un proveedor que no verifica correos y apropiarse de su cuenta en MisLukas. Además, desde el perfil el usuario podrá ver qué métodos de acceso tiene vinculados y desvincularlos.

**Requisito de Apple sobre opciones de inicio de sesión.** Las pautas de revisión de la App Store (sección 4.8) establecen que, si una aplicación usa un servicio de inicio de sesión de terceros o redes sociales, como Google, para crear o autenticar la cuenta principal del usuario, también debe ofrecer una opción equivalente que cumpla ciertas condiciones de privacidad:

- Limitar los datos recolectados al nombre y al correo del usuario.
- Permitir que el usuario mantenga su correo privado al crear la cuenta.
- No recolectar interacciones con la app con fines publicitarios sin consentimiento.

"Iniciar sesión con Apple" cumple estas condiciones. Por eso, cuando MisLukas agregue Google, agregará también Apple en la versión de iOS, con la misma visibilidad y jerarquía. Presentar la opción de Apple de forma secundaria o escondida también puede ser motivo de rechazo. Por esa razón los bocetos ya muestran ambos botones en igualdad de condiciones.

Un detalle práctico: con la opción de ocultar el correo, Apple entrega una dirección de reenvío única en lugar del correo real. El sistema de MisLukas debe aceptar ese tipo de direcciones y enviar a ellas los correos de seguridad, sin exigir el correo real del usuario.

## 8.11 Mejoras de seguridad futuras

Las siguientes medidas se identificaron como valiosas, pero se posponen por su complejidad o porque dependen de que la aplicación esté en producción. Se listan en orden de prioridad.

| Mejora                                         | Qué aporta                                                                                                                                                      | Por qué se pospone                                                                                        |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Autenticación de dos factores (2FA)            | Protege la cuenta aunque la contraseña se filtre, pidiendo un código de una aplicación autenticadora. Supabase Auth ya ofrece soporte para este tipo de factor. | Agrega fricción al inicio de sesión; se ofrecerá como opción activable desde el perfil.                   |
| Protección contra contraseñas filtradas        | Rechaza contraseñas que aparecen en filtraciones conocidas.                                                                                                     | Disponible desde el plan Pro de Supabase; se activará al pasar a producción.                              |
| Alertas de nuevo dispositivo                   | Envía un correo cuando se inicia sesión desde un dispositivo no reconocido, con opción de cerrar esa sesión.                                                    | Requiere registrar y reconocer dispositivos (tabla dispositivos, 6.4.1).                                  |
| Auditoría y gestión de sesiones                | Permite al usuario ver dónde tiene sesiones abiertas y cerrarlas individualmente. Supabase registra eventos de autenticación en sus registros de auditoría.     | Requiere diseño de interfaz y la tabla de dispositivos.                                                   |
| Certificate pinning                            | Protege la comunicación incluso ante certificados falsos instalados en el dispositivo.                                                                          | Requiere un procedimiento de rotación de certificados (8.7).                                              |
| Detección de dispositivos con root o jailbreak | Advierte al usuario o limita funciones cuando el sistema operativo fue modificado y sus protecciones pueden estar desactivadas.                                 | Puede generar falsos positivos y afectar a usuarios legítimos; requiere definir la política de respuesta. |
| Inicio de sesión sin contraseña (passkeys)     | Elimina el riesgo de contraseñas débiles o reutilizadas usando credenciales criptográficas del dispositivo.                                                     | Tecnología en adopción; se evaluará según el soporte en los dispositivos del público objetivo.            |
| Pruebas de penetración                         | Una revisión externa que busque vulnerabilidades que el equipo no detectó.                                                                                      | Se realizará antes del lanzamiento comercial.                                                             |

La seguridad de una aplicación no es un estado que se alcanza, sino un proceso que se mantiene. Las medidas del MVP cubren los riesgos principales identificados en el modelo de amenazas; estas mejoras permitirán elevar el nivel de protección a medida que la aplicación crezca y su base de usuarios lo justifique.
