# 4. Funcionalidades y requerimientos

Esta sección traduce el problema, los usuarios y las historias de usuario de las secciones anteriores en funcionalidades concretas y requisitos verificables. Primero describimos qué hace la aplicación en su versión MVP y qué queda para después. Luego detallamos los requisitos funcionales, que definen qué debe hacer el sistema, y los no funcionales, que definen cómo debe hacerlo.

## 4.1 Funcionalidades del MVP

Las funcionalidades del MVP se seleccionaron con un criterio sencillo: solo entra lo que es necesario para completar el ciclo de registrar, entender y proyectar, y lo que exige la seguridad de una aplicación que maneja datos financieros. Todo lo demás se pospuso.

**Registro, inicio de sesión y recuperación de contraseña.**

El usuario crea una cuenta con su correo y una contraseña que debe cumplir requisitos mínimos de seguridad, verifica su correo e inicia sesión. Si olvida la contraseña, puede restablecerla con un código de un solo uso enviado a su correo. Una vez iniciada la sesión, las siguientes aperturas de la aplicación se desbloquean con huella, reconocimiento facial o PIN. Aunque la autenticación no es la funcionalidad que el usuario busca al descargar la app, es la base de todo lo demás: sin ella no hay forma de proteger los datos ni de recuperarlos al cambiar de celular.

**Dashboard con el disponible del mes.**

La pantalla de inicio responde a la pregunta que el usuario se hace con más frecuencia: ¿cuánto me queda? Muestra el disponible del mes (ingresos menos gastos), las alertas de presupuesto activas y los últimos movimientos registrados, con acceso directo al registro de un nuevo gasto.

**Registro de gasto por foto o manual.**

Es la funcionalidad central del MVP. El usuario puede fotografiar un recibo para que la aplicación extraiga el valor total y sugiera una categoría, o registrar el movimiento a mano cuando no tiene recibo. En ambos casos puede revisar y corregir los datos antes de guardar. El registro manual también se usa para los ingresos.

**Categorías y alertas de presupuesto.**

La aplicación trae un conjunto de categorías predeterminadas (Mercado, Transporte, Ocio, Servicios, Restaurantes, Otros) y permite asignar un presupuesto mensual a cada una. Cuando el gasto de una categoría se acerca al límite, se muestra una alerta en la pantalla de inicio y, si el usuario lo permite, una notificación en el celular.

**Reportes por categoría y comparación mensual.**

La pantalla de reportes muestra el total gastado en el mes, su distribución por categoría en un gráfico y la variación de cada categoría frente al mes anterior.

**Simulador de ahorro.**

A partir del ahorro real de los últimos tres meses, el simulador proyecta cuánto acumularía el usuario en un horizonte de uno a diez años, sin interés y con una tasa estimada, y le permite explorar qué pasaría si aumenta su aporte mensual.

**Funcionamiento offline con sincronización.**

Todas las funciones de registro y consulta trabajan sobre la base de datos del dispositivo, por lo que la aplicación funciona igual con o sin conexión. Cuando hay internet, los cambios se sincronizan automáticamente con la nube.

Tabla descriptiva de cada funcionalidad de cada pantalla con su respectiva historia de usuario

| **Funcionalidad**                         | **Pantalla(s)**                 | **Historias de usuario**   |
| ----------------------------------------- | ------------------------------- | -------------------------- |
| Registro, inicio de sesión y recuperación | Inicio de sesión / Registro     | HU-01, HU-02, HU-03, HU-04 |
| Dashboard con disponible del mes          | Inicio                          | HU-08                      |
| Registro por foto o manual                | Nuevo gasto, Confirma los datos | HU-05, HU-06               |
| Categorías y alertas de presupuesto       | Inicio                          | HU-08                      |
| Reportes y comparación mensual            | Reportes                        | HU-09                      |
| Simulador de ahorro                       | Simulador                       | HU-10                      |
| Funcionamiento offline                    | Transversal a todas             | HU-07                      |

## 4.2 Funcionalidades Futuras

Las siguientes funcionalidades se identificaron durante el diseño, pero se dejaron fuera del MVP. No se descartan: la arquitectura se diseñó para que puedan incorporarse sin rehacer lo construido. En la tabla indicamos por qué se pospuso cada una y qué se hizo desde ahora para facilitar su implementación.

| **Funcionalidad**                   | **Por qué se pospone**                                                                                                                                                                  | **Cómo se prepara desde el MVP**                                                                                                              |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Inicio de sesión con Google y Apple | Requiere configurar credenciales en las consolas de Google y Apple, y en iOS implica cumplir requisitos adicionales de la App Store. No es necesario para validar la idea del producto. | Supabase Auth ya soporta estos proveedores. En la pantalla de inicio de sesión se dejaron los botones con la etiqueta "Próximamente".         |
| Autenticación en dos pasos (2FA)    | Agrega fricción al inicio de sesión. En el MVP, la biometría y el bloqueo por intentos ofrecen un nivel de protección suficiente para una primera versión.                              | El flujo de autenticación está separado en su propio módulo, lo que permite agregar un segundo paso sin afectar el resto de la aplicación.    |
| Metas de ahorro                     | El simulador ya cumple la función de motivar el ahorro. Las metas requieren un módulo propio de seguimiento y notificaciones.                                                           | El cálculo de ahorro promedio del simulador se reutiliza para estimar en cuánto tiempo se alcanza una meta.                                   |
| Múltiples cuentas o billeteras      | Complica la interfaz y el modelo de datos. La mayoría de usuarios del segmento objetivo necesita primero ver el total, no separarlo.                                                    | El modelo de datos contempla un campo de cuenta en cada movimiento, con un valor por defecto en el MVP.                                       |
| Exportación de reportes             | Es útil, pero no afecta el ciclo principal de la aplicación.                                                                                                                            | Los reportes se calculan en una capa independiente de la interfaz, por lo que se pueden generar en otros formatos.                            |
| Perfil completo                     | Se diseña en la siguiente iteración de bocetos.                                                                                                                                         | El MVP incluye las funciones mínimas de perfil exigidas por seguridad y por las tiendas (cerrar sesión, cambiar contraseña, eliminar cuenta). |
| Categorías personalizadas           | Las categorías predeterminadas cubren la mayoría de gastos del público objetivo.                                                                                                        | Las categorías se guardan en una tabla propia, no como valores fijos en el código.                                                            |

## 4.3 Requerimientos funcionales

Los requisitos funcionales describen lo que el sistema debe hacer. Se agrupan por módulo y cada uno tiene un identificador único, una prioridad según el método MoSCoW y la historia de usuario de la que se deriva. Esa relación permite rastrear cualquier requisito hasta la necesidad del usuario que lo originó y, en sentido contrario, verificar que ninguna historia quede sin cubrir.

4.3.1 Requerimientos funcionales del módulo de autenticación

| ID    | Descripción                                                                                                                                                        | Prioridad | HU    |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------- | ----- |
| RF-01 | El sistema debe permitir crear una cuenta con nombre, correo electrónico y contraseña.                                                                             | Must      | HU-01 |
| RF-02 | El sistema debe validar que la contraseña tenga mínimo 8 caracteres, una mayúscula, un número y un símbolo, y mostrar en tiempo real qué requisitos se cumplen.    | Must      | HU-01 |
| RF-03 | El sistema debe exigir la aceptación de los términos y de la política de tratamiento de datos personales antes de crear la cuenta.                                 | Must      | HU-01 |
| RF-04 | El sistema debe enviar un correo de verificación y no permitir el uso completo de la cuenta hasta que el correo sea verificado.                                    | Must      | HU-01 |
| RF-05 | El sistema debe permitir iniciar sesión con correo y contraseña.                                                                                                   | Must      | HU-02 |
| RF-06 | El sistema debe mostrar un mensaje genérico ante credenciales incorrectas, sin indicar si el error está en el correo o en la contraseña.                           | Must      | HU-02 |
| RF-07 | El sistema debe bloquear temporalmente el inicio de sesión después de cinco intentos fallidos en quince minutos, e informar al usuario el tiempo de espera.        | Must      | HU-02 |
| RF-08 | El sistema debe permitir solicitar la recuperación de contraseña mediante un código de un solo uso enviado al correo, con un tiempo de expiración de diez minutos. | Must      | HU-03 |
| RF-09 | El sistema debe mostrar el mismo mensaje al solicitar la recuperación, exista o no una cuenta con el correo ingresado.                                             | Must      | HU-03 |
| RF-10 | El sistema debe cerrar todas las sesiones activas del usuario después de un cambio de contraseña.                                                                  | Must      | HU-03 |
| RF-11 | El sistema debe mantener la sesión iniciada entre aperturas de la aplicación hasta que el usuario la cierre o el token expire.                                     | Must      | HU-02 |
| RF-12 | El sistema debe permitir desbloquear la aplicación con huella, reconocimiento facial o un PIN de cuatro dígitos.                                                   | Should    | HU-04 |
| RF-13 | El sistema debe permitir cerrar sesión, eliminando los datos locales del dispositivo.                                                                              | Must      | HU-02 |

4.3.2 Requerimientos funcionales del módulo de movimientos

| ID    | Descripción                                                                                                                                       | Prioridad | HU    |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------- | --------- | ----- |
| RF-14 | El sistema debe permitir capturar la foto de un recibo con la cámara o seleccionarla desde la galería.                                            | Must      | HU-05 |
| RF-15 | El sistema debe extraer el valor total del recibo mediante reconocimiento de texto ejecutado en el dispositivo, sin requerir conexión a internet. | Must      | HU-05 |
| RF-16 | El sistema debe sugerir una categoría a partir del nombre del comercio detectado en el recibo.                                                    | Should    | HU-05 |
| RF-17 | El sistema debe permitir revisar y editar el valor, la categoría y la nota antes de guardar el movimiento.                                        | Must      | HU-05 |
| RF-18 | El sistema debe informar al usuario cuando no logre leer el recibo y permitirle ingresar el valor manualmente.                                    | Must      | HU-05 |
| RF-19 | El sistema debe permitir registrar manualmente un gasto o un ingreso con valor, categoría, fecha y nota opcional.                                 | Must      | HU-06 |
| RF-20 | El sistema debe rechazar valores vacíos, iguales a cero o negativos.                                                                              | Must      | HU-06 |
| RF-21 | El sistema debe mostrar los últimos movimientos en la pantalla de inicio, ordenados del más reciente al más antiguo.                              | Must      | HU-06 |
| RF-22 | El sistema debe permitir consultar el historial completo de movimientos y filtrarlo por mes y categoría.                                          | Should    | HU-06 |
| RF-23 | El sistema debe permitir editar y eliminar un movimiento registrado.                                                                              | Must      | HU-06 |
| RF-24 | El sistema debe guardar todo movimiento primero en la base de datos local, con estado "pendiente de sincronizar" si no hay conexión.              | Must      | HU-07 |
| RF-25 | El sistema debe sincronizar automáticamente los movimientos pendientes cuando detecte conexión a internet.                                        | Must      | HU-07 |
| RF-26 | El sistema debe evitar la creación de registros duplicados durante la sincronización, usando un identificador único generado en el dispositivo.   | Must      | HU-07 |

4.3.3 Requerimientos funcionales del módulo de presupuesto

| ID    | Descripción                                                                                                                                                                       | Prioridad | HU    |
| ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- | ----- |
| RF-27 | El sistema debe incluir las categorías predeterminadas Mercado, Transporte, Ocio, Servicios, Restaurantes y Otros para gastos, e Ingreso para ingresos.                           | Must      | HU-08 |
| RF-28 | El sistema debe permitir definir un presupuesto mensual para cada categoría de gasto.                                                                                             | Must      | HU-08 |
| RF-29 | El sistema debe calcular y mostrar el disponible del mes como la diferencia entre ingresos y gastos del mes actual.                                                               | Must      | HU-08 |
| RF-30 | El sistema debe mostrar una alerta en la pantalla de inicio cuando el gasto de una categoría alcance el 75% de su presupuesto, indicando el porcentaje usado y el monto restante. | Must      | HU-08 |
| RF-31 | El sistema debe mostrar una alerta distinta cuando el gasto de una categoría supere el 100% de su presupuesto.                                                                    | Should    | HU-08 |
| RF-32 | El sistema debe enviar una notificación local al generarse una alerta, si el usuario lo ha permitido.                                                                             | Should    | HU-08 |

4.3.4 Requerimientos funcionales del módulo de reportes

| ID    | Descripción                                                                                                                                    | Prioridad | HU    |
| ----- | ---------------------------------------------------------------------------------------------------------------------------------------------- | --------- | ----- |
| RF-33 | El sistema debe mostrar el total gastado en el mes actual.                                                                                     | Must      | HU-09 |
| RF-34 | El sistema debe mostrar la distribución de gastos por categoría en un gráfico de dona con el porcentaje de cada una.                           | Must      | HU-09 |
| RF-35 | El sistema debe mostrar la variación porcentual de cada categoría frente al mes anterior, con los aumentos en rojo y las reducciones en verde. | Must      | HU-09 |
| RF-36 | El sistema debe mostrar un mensaje orientador cuando no existan movimientos en el mes consultado.                                              | Must      | HU-09 |
| RF-37 | El sistema debe permitir consultar reportes de meses anteriores.                                                                               | Could     | HU-09 |

4.3.5 Requerimientos funcionales del módulo del simulador

| ID    | Descripción                                                                                                                                                                               | Prioridad | HU    |
| ----- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- | ----- |
| RF-38 | El sistema debe calcular el ahorro promedio mensual como el promedio de la diferencia entre ingresos y gastos de los últimos tres meses completos.                                        | Should    | HU-10 |
| RF-39 | El sistema debe informar al usuario cuando no tenga suficientes datos para calcular el promedio o cuando este sea negativo.                                                               | Should    | HU-10 |
| RF-40 | El sistema debe permitir seleccionar un horizonte de tiempo entre 1 y 10 años.                                                                                                            | Should    | HU-10 |
| RF-41 | El sistema debe calcular el ahorro acumulado sin interés (aporte × meses) y con interés compuesto a una tasa estimada del 7% efectivo anual, y recalcular al cambiar cualquier parámetro. | Should    | HU-10 |
| RF-42 | El sistema debe permitir ajustar el aporte mensual en pasos de \$50.000 y mostrar la diferencia frente al escenario inicial.                                                              | Could     | HU-10 |
| RF-43 | El sistema debe mostrar un aviso indicando que la simulación es estimada y no constituye asesoría financiera.                                                                             | Must      | HU-10 |

4.3.6 Requerimientos funcionales del módulo de perfil

| ID    | Descripción                                                                                                                                              | Prioridad | HU    |
| ----- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- | ----- |
| RF-44 | El sistema debe permitir consultar y editar el nombre del usuario.                                                                                       | Should    | —     |
| RF-45 | El sistema debe permitir cambiar la contraseña, solicitando la contraseña actual.                                                                        | Must      | HU-03 |
| RF-46 | El sistema debe permitir activar y desactivar el desbloqueo biométrico.                                                                                  | Should    | HU-04 |
| RF-47 | El sistema debe mostrar el estado de sincronización y la cantidad de cambios pendientes.                                                                 | Should    | HU-07 |
| RF-48 | El sistema debe permitir eliminar la cuenta desde la aplicación, previa confirmación, borrando los datos del usuario en el dispositivo y en el servidor. | Must      | —     |
| RF-49 | El sistema debe permitir consultar la política de tratamiento de datos y los términos de uso.                                                            | Must      | —     |

Los requisitos RF-44, RF-48 y RF-49 no provienen de una historia de usuario, sino de obligaciones legales y de las políticas de publicación de Google Play y App Store, que exigen que las aplicaciones con registro permitan eliminar la cuenta desde la propia aplicación.

## 4.4 requerimientos no funcionales

Los requisitos no funcionales definen las cualidades del sistema: qué tan seguro, rápido, disponible y fácil de usar debe ser. Para que no se queden en declaraciones generales, cada requisito incluye un criterio de verificación que permite comprobar si se cumple.

4.4.1 Requerimientos no funcionales de seguridad

| ID     | Requisito                                                                                                                                                    | Criterio de verificación                                                                        |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| RNF-01 | El servidor debe limitar los intentos de inicio de sesión, registro y recuperación de contraseña por cuenta y por dirección IP.                              | Una prueba automatizada con más de cinco intentos fallidos en quince minutos recibe un bloqueo. |
| RNF-02 | Las contraseñas nunca deben almacenarse ni transmitirse en texto plano; el servidor las guarda con un algoritmo de hash seguro gestionado por Supabase Auth. | Revisión de la configuración del backend y de la base de datos.                                 |
| RNF-03 | Toda comunicación entre la aplicación y el servidor debe realizarse sobre HTTPS con TLS.                                                                     | Inspección del tráfico de red: no existen solicitudes por HTTP.                                 |
| RNF-04 | La base de datos local debe estar cifrada, con la clave almacenada en el almacenamiento seguro del sistema (Keystore en Android, Keychain en iOS).           | El archivo de la base de datos extraído del dispositivo no es legible sin la clave.             |
| RNF-05 | Los tokens de sesión deben guardarse únicamente en el almacenamiento seguro del sistema.                                                                     | Revisión del código: no hay tokens en almacenamiento no cifrado.                                |
| RNF-06 | Todas las tablas del servidor deben tener Row Level Security activado, de modo que cada usuario solo acceda a sus propios registros.                         | Prueba con dos usuarios: ninguno puede leer ni modificar los datos del otro.                    |
| RNF-07 | Todas las consultas a bases de datos, locales y remotas, deben ser parametrizadas.                                                                           | Revisión de código y pruebas con entradas de inyección SQL.                                     |
| RNF-08 | La aplicación debe bloquearse y solicitar biometría o PIN después de cinco minutos en segundo plano.                                                         | Prueba manual en ambos sistemas operativos.                                                     |

4.4.2 requerimientos no funcionales de disponibilidad y funcionamiento offline

| ID     | Requisito                                                                                                                  | Criterio de verificación                                                                    |
| ------ | -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| RNF-09 | Las funciones de registro, consulta de movimientos, reportes, alertas y simulador deben funcionar sin conexión a internet. | Pruebas en modo avión: todas las funciones listadas operan con normalidad.                  |
| RNF-10 | Los cambios pendientes deben sincronizarse en menos de un minuto después de recuperar la conexión.                         | Medición del tiempo entre la reconexión y la confirmación de sincronización.                |
| RNF-11 | Ningún dato registrado sin conexión debe perderse si la aplicación se cierra antes de sincronizar.                         | Registrar sin conexión, cerrar la app, reconectar y verificar que los datos se sincronizan. |

4.4.3 requerimientos no funcionales de rendimiento

| ID     | Requisito                                                                                                              | Criterio de verificación                                          |
| ------ | ---------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| RNF-12 | El registro completo de un gasto por foto, desde tocar "Nuevo gasto" hasta guardarlo, debe tomar menos de 15 segundos. | Pruebas con usuarios cronometrando el flujo completo.             |
| RNF-13 | El reconocimiento de texto de un recibo debe completarse en menos de 3 segundos en un dispositivo de gama media.       | Medición en dispositivos de prueba.                               |
| RNF-14 | La aplicación debe abrir y mostrar la pantalla de inicio en menos de 3 segundos después del desbloqueo.                | Medición en arranque en frío.                                     |
| RNF-15 | Las animaciones y transiciones deben mantenerse fluidas, sin caídas perceptibles de cuadros.                           | Análisis con las herramientas de rendimiento de Flutter DevTools. |

4.4.4 requerimientos no funcionales de accesibilidad y usabilidad

| ID     | Requisito                                                                                                                | Criterio de verificación                                       |
| ------ | ------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------- |
| RNF-16 | Registrar un gasto no debe requerir más de cuatro toques en el flujo por foto.                                           | Conteo de interacciones en el prototipo y en la aplicación.    |
| RNF-17 | Todos los elementos interactivos deben tener un área táctil mínima de 48 × 48 dp.                                        | Revisión del diseño y de la implementación.                    |
| RNF-18 | El contraste entre texto y fondo debe cumplir como mínimo la relación 4,5:1 establecida en las pautas WCAG 2.1 nivel AA. | Verificación con herramientas de contraste.                    |
| RNF-19 | La interfaz debe adaptarse al tamaño de texto configurado en el sistema sin que el contenido se corte ni se superponga.  | Pruebas con el tamaño de fuente máximo del sistema.            |
| RNF-20 | Los íconos y botones deben tener etiquetas accesibles para lectores de pantalla (TalkBack y VoiceOver).                  | Recorrido de las pantallas principales con lector de pantalla. |
| RNF-21 | Los mensajes de error deben explicar qué pasó y cómo corregirlo, en lenguaje claro y sin términos técnicos.              | Revisión de todos los mensajes de la aplicación.               |

4.4.5 requerimientos no funcionales del cumplimiento legal

| ID     | Requisito                                                                                                                                                                                                                       | Criterio de verificación                                                           |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| RNF-22 | La aplicación debe cumplir la Ley 1581 de 2012 de protección de datos personales: política de tratamiento disponible, consentimiento previo y expreso, y mecanismos para que el titular conozca, actualice y suprima sus datos. | Revisión de la política, del flujo de registro y de la función de eliminar cuenta. |
| RNF-23 | Solo deben recolectarse los datos estrictamente necesarios para el funcionamiento de la aplicación.                                                                                                                             | Revisión del modelo de datos frente a las funcionalidades.                         |
| RNF-24 | La aplicación debe cumplir las políticas de publicación de Google Play y App Store, incluida la declaración de uso de datos y la eliminación de cuenta desde la app.                                                            | Lista de chequeo de publicación de cada tienda.                                    |

4.4.6 requerimientos no funcionales de compatibilidad

| ID     | Requisito                                                                                                                                                                                       | Criterio de verificación                                               |
| ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| RNF-25 | La aplicación debe funcionar en Android 8.0 o superior y en iOS 15 o superior. Estas versiones mínimas se confirmarán al inicio del desarrollo según los requisitos de los paquetes utilizados. | Pruebas en emuladores y dispositivos físicos de las versiones mínimas. |
| RNF-26 | La interfaz debe adaptarse a pantallas de celular entre 4,7 y 6,9 pulgadas, en orientación vertical.                                                                                            | Pruebas en distintos tamaños de pantalla.                              |
| RNF-27 | Android e iOS deben compartir un mismo código base en Flutter, con diferencias solo donde el sistema operativo lo requiera.                                                                     | Revisión del repositorio.                                              |

4.4.7 requerimientos no funcionales de mantenibilidad

| ID     | Requisito                                                                                                                                    | Criterio de verificación                  |
| ------ | -------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| RNF-28 | El código debe organizarse en capas (presentación, dominio y datos), de modo que cambiar la fuente de datos no afecte la interfaz.           | Revisión de la arquitectura del proyecto. |
| RNF-29 | La lógica de negocio (cálculos del simulador, disponible del mes, alertas) debe tener una cobertura de pruebas unitarias de al menos el 70%. | Reporte de cobertura de pruebas.          |
