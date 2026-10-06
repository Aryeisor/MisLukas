# 3. Usuarios Objetivó

## 3.1 Público objetivo

MisLukas está dirigida a jóvenes y adultos jóvenes, aproximadamente entre los 18 y los 35 años, que están empezando a manejar su propio dinero o que tienen ingresos que cambian de un mes a otro. No se trata de un rango de edad elegido al azar: es la etapa en la que la mayoría de personas pasa de depender de otros a asumir sus propios gastos, y en la que se forman los hábitos financieros que suelen mantenerse después.

Dentro de ese grupo identificamos tres segmentos principales:

**Estudiantes universitarios.** Reciben dinero de su familia, de un trabajo de medio tiempo o de trabajos ocasionales. Sus ingresos son bajos e irregulares, y sus gastos se concentran en transporte, comida y ocio. Para ellos el problema no es administrar grandes sumas, sino que el dinero alcance hasta el próximo ingreso.

**Personas en su primer empleo.** Tienen por primera vez un salario fijo y, con él, obligaciones nuevas: arriendo, servicios, mercado. Es común que al inicio gasten sin un control claro porque sienten que el sueldo es suficiente, hasta que descubren que no les queda nada para ahorrar.

**Trabajadores independientes y freelancers.** Sus ingresos varían mes a mes según los proyectos que consigan. Necesitan saber cuánto gastan en promedio para planear los meses flojos, y suelen combinar varios medios de pago: efectivo, transferencias, billeteras digitales y tarjeta.

**Características comunes del público objetivo:**

- Usan el celular como herramienta principal para casi todo, incluidos pagos y trámites.
- Pagan con varios medios a la vez, por lo que ninguna aplicación bancaria les muestra el panorama completo de sus gastos.
- Tienen poco tiempo y poca paciencia para herramientas complejas; si algo toma demasiados pasos, lo abandonan.
- No siempre cuentan con conexión estable o datos ilimitados.
- Desconfían, con razón, de entregar sus claves bancarias a aplicaciones de terceros.

**Fuera del alcance.** MisLukas no está diseñada para la contabilidad de negocios, el manejo de inversiones o el control financiero de empresas. Tampoco busca reemplazar la asesoría de un profesional financiero. Definir quién no es usuario objetivo es tan importante como definir quién sí lo es, porque evita que el producto crezca en direcciones que no aportan a su propósito central.

## 3.2 User persona

Una **user persona** es un perfil ficticio, pero realista, que representa al usuario típico de la aplicación. Sirve para tomar decisiones de diseño pensando en una persona concreta y no en un usuario abstracto. Para MisLukas definimos una persona principal, que es la que aparece en los bocetos, y una persona secundaria que representa al segmento estudiantil.

Persona principal Camila Rodríguez

| **Edad**                       | 24 años                                                                                         |
| ------------------------------ | ----------------------------------------------------------------------------------------------- |
| **Ciudad**                     | Bogotá                                                                                          |
| **Ocupación**                  | Diseñadora gráfica junior en una agencia, con proyectos freelance ocasionales                   |
| **Ingresos**                   | Salario de \$3.800.000 mensuales más trabajos freelance que varían entre \$0 y \$800.000 al mes |
| **Medios de pago**             | Tarjeta débito, Nequi y efectivo                                                                |
| **Relación con la tecnología** | Alta. Usa el celular para pagos, transporte, domicilios y trabajo                               |

**Contexto.** Camila vive sola desde hace un año, cuando consiguió su primer empleo formal. Paga arriendo, servicios, mercado y se mueve en Transmilenio. Le gusta salir con sus amigos los fines de semana y compra café casi todos los días cerca de la oficina. Sus ingresos le alcanzan, pero al final de cada mes se pregunta en qué se le fue la plata, porque no logra ahorrar lo que se había propuesto.

**Hábitos.**

- Revisa el saldo de su cuenta varias veces a la semana, pero nunca ha llevado un registro de sus gastos por más de dos semanas seguidas.
- Guarda los recibos del supermercado en la billetera "por si acaso" y termina botándolos.
- Intentó usar una hoja de cálculo y una aplicación de registro manual; ambas las abandonó al poco tiempo.

**Frustraciones.**

- "Sé cuánto me pagan, pero no sé en qué se me va."
- Anotar cada gasto le parece aburrido y siempre se le olvida.
- Las aplicaciones que ha probado le piden conectar su cuenta bancaria y eso no le da confianza.
- Siente que ahorrar \$100.000 al mes no sirve de mucho, entonces lo pospone.

**Objetivos.**

- Saber cuánto le queda disponible en el mes sin tener que hacer cuentas.
- Reducir lo que gasta en ocio sin dejar de salir.
- Empezar a ahorrar para hacer una especialización en dos o tres años.

**Qué necesita de MisLukas.** Registrar sus gastos casi sin esfuerzo, recibir un aviso antes de pasarse del presupuesto y ver una cifra concreta de cuánto podría tener ahorrado si mantiene el hábito.

Persona secundaria Andrés Gómez

| **Edad**           | 20 años                                                                               |
| ------------------ | ------------------------------------------------------------------------------------- |
| **Ciudad**         | Cúcuta                                                                                |
| **Ocupación**      | Estudiante de quinto semestre de Ingeniería                                           |
| **Ingresos**       | Mesada familiar de \$600.000 más trabajos ocasionales como monitor o haciendo diseños |
| **Medios de pago** | Efectivo y Nequi                                                                      |

Andrés maneja poco dinero, pero cada peso cuenta. Sus gastos principales son transporte, almuerzos, fotocopias y salidas. Casi siempre se queda sin plata la última semana del mes. Muchos de sus gastos son en efectivo y no tienen recibo, y en la universidad la conexión a internet es inestable. Para él son clave el registro manual rápido y que la aplicación funcione sin conexión.

## 3.3 Escenarios de uso

Los escenarios describen situaciones cotidianas en las que el usuario interactúa con la aplicación. Permiten verificar que el diseño responda a necesidades reales y no solo a funciones en abstracto.

**Escenario 1: Registrar el mercado con una foto.**

Camila sale del supermercado con las bolsas en una mano y el recibo en la otra. Abre MisLukas, toca "Nuevo gasto", deja seleccionada la opción "Foto del recibo" y le toma la foto. La aplicación detecta un total de \$87.400 y sugiere la categoría Mercado. Camila confirma y guarda. Todo el proceso toma menos de quince segundos y puede botar el recibo tranquila.

**Escenario 2: Registrar un gasto sin recibo y sin conexión.**

Andrés recarga su tarjeta de transporte con \$10.000 en efectivo. Va en el bus y no tiene datos. Abre la aplicación, elige "Registro manual", escribe el valor y selecciona Transporte. El gasto queda guardado en el celular con el estado "pendiente de sincronizar". Cuando llega a la universidad y se conecta al wifi, la aplicación sincroniza el registro sin que él tenga que hacer nada.

**Escenario 3: Recibir una alerta de presupuesto.**

Es 22 de septiembre y Camila registra otra compra de mercado. Al guardarla, la pantalla de inicio muestra la alerta "Presupuesto de mercado al 78%. Te quedan \$253.000 para fin de mes". Camila decide aplazar una compra que no era urgente para no pasarse del límite.

**Escenario 4: Revisar el mes en los reportes.**

A final de mes, Camila entra a Reportes y ve que el ocio subió un 31% frente a agosto. Revisando los movimientos, identifica que la mayor parte fueron domicilios y cafés. Se propone reducir esa categoría el mes siguiente.

**Escenario 5: Proyectar el ahorro.**

Camila entra al simulador y ve que ahorra en promedio \$420.000 al mes. Mueve el horizonte a tres años y descubre que, con un rendimiento del 7% efectivo anual, llegaría a \$16.716.800. La sugerencia le muestra que, si ahorra \$50.000 más al mes, llegaría a \$18.707.000. Esa cifra concreta le permite ver que la especialización que quiere hacer es alcanzable.

**Escenario 6: Cambiar de celular.**

A Camila le roban el celular. Compra uno nuevo, instala MisLukas e inicia sesión con su correo y contraseña. Sus movimientos, categorías y presupuestos se descargan desde la nube. Como la base de datos del celular robado está cifrada y protegida con biometría, quien lo tenga no puede ver su información financiera.

**Escenario 7: Olvidar la contraseña.**

Andrés no recuerda su contraseña. En la pantalla de inicio de sesión toca "¿Olvidaste tu contraseña?", ingresa su correo y recibe un código de verificación. Crea una contraseña nueva y la aplicación le informa que se cerró la sesión en sus otros dispositivos por seguridad.

## 3.4 Historias de usuario

Las historias de usuario expresan las funcionalidades desde el punto de vista de quien las usa, con el formato _"*Como \[tipo de usuario\], quiero \[acción\], para \[beneficio\]*"_. Cada historia incluye criterios de aceptación en formato _Dado / Cuando / Entonces_, que definen de forma verificable cuándo la funcionalidad se considera terminada. La prioridad se asigna con el método MoSCoW: **Must** (obligatoria para el MVP), **Should** (importante), **Could** (deseable) y **Won't** (fuera de esta versión).

**Módulo de autenticación**

**HU-01 · Registro de cuenta** · Prioridad: Must

Como usuario nuevo, quiero crear una cuenta con mi correo y una contraseña, para guardar mis datos de forma segura y acceder a ellos desde cualquier dispositivo.

Criterios de aceptación:

- **Dado** que estoy en la pestaña "Registrarse", **cuando** ingreso una contraseña que no cumple los requisitos mínimos, **entonces** el sistema muestra cuáles requisitos faltan y mantiene deshabilitado el botón "Crear cuenta".
- **Dado** que las dos contraseñas no coinciden, **cuando** intento continuar, **entonces** se muestra un mensaje de error debajo del campo de confirmación.
- **Dado** que no he aceptado la política de tratamiento de datos, **cuando** intento crear la cuenta, **entonces** el sistema no me permite continuar.
- **Dado** que todos los datos son válidos, **cuando** toco "Crear cuenta", **entonces** recibo un correo para verificar mi cuenta.

**HU-02 · Inicio de sesión** · Prioridad: Must

Como usuario registrado, quiero iniciar sesión con mi correo y contraseña, para acceder a mi información financiera.

Criterios de aceptación:

- **Dado** que ingreso credenciales correctas, **cuando** toco "Iniciar sesión", **entonces** accedo a la pantalla de inicio.
- **Dado** que ingreso un correo o una contraseña incorrectos, **cuando** intento iniciar sesión, **entonces** el sistema muestra el mensaje genérico "Correo o contraseña incorrectos", sin indicar cuál de los dos falló.
- **Dado** que he fallado cinco intentos en quince minutos, **cuando** intento de nuevo, **entonces** el sistema bloquea temporalmente el inicio de sesión e indica cuánto tiempo debo esperar.

**HU-03 · Recuperación de contraseña** · Prioridad: Must

Como usuario que olvidó su contraseña, quiero restablecerla desde mi correo, para recuperar el acceso a mi cuenta.

Criterios de aceptación:

- **Dado** que ingreso un correo, **cuando** solicito la recuperación, **entonces** el sistema muestra el mismo mensaje exista o no una cuenta con ese correo.
- **Dado** que recibí un código, **cuando** lo ingreso después de su tiempo de expiración, **entonces** el sistema lo rechaza y me permite solicitar uno nuevo.
- **Dado** que creo una nueva contraseña válida, **cuando** la guardo, **entonces** se cierran las sesiones activas en mis otros dispositivos.

**HU-04 · Desbloqueo con biometría** · Prioridad: Should

Como usuario con sesión activa, quiero desbloquear la aplicación con mi huella o mi rostro, para entrar rápido sin exponer mis datos si alguien toma mi celular.

Criterios de aceptación:

- **Dado** que activé la biometría, **cuando** abro la aplicación, **entonces** se solicita la huella o el reconocimiento facial antes de mostrar cualquier información.
- **Dado** que la biometría falla o no está disponible, **cuando** elijo "Usar PIN", **entonces** puedo desbloquear con mi PIN de cuatro dígitos.

**Módulo de movimientos**

**HU-05 · Registro de gasto por foto** · Prioridad: Must

Como usuario, quiero registrar un gasto tomando una foto del recibo, para no tener que escribir el valor ni clasificarlo manualmente.

Criterios de aceptación:

- **Dado** que elijo "Foto del recibo", **cuando** tomo la foto, **entonces** la aplicación muestra el valor detectado y una categoría sugerida.
- **Dado** que el valor detectado es incorrecto, **cuando** lo edito, **entonces** se guarda el valor que yo ingresé.
- **Dado** que la aplicación no logra leer el recibo, **cuando** termina el procesamiento, **entonces** me informa y me permite ingresar el valor manualmente.
- **Dado** que no tengo conexión a internet, **cuando** tomo la foto, **entonces** el reconocimiento funciona igual, porque se procesa en el dispositivo.

**HU-06 · Registro manual de gasto o ingreso** · Prioridad: Must

Como usuario, quiero registrar un gasto o un ingreso escribiendo el valor y eligiendo la categoría, para anotar movimientos que no tienen recibo.

Criterios de aceptación:

- **Dado** que elijo "Registro manual", **cuando** ingreso un valor y una categoría, **entonces** puedo guardar el movimiento.
- **Dado** que dejo el valor vacío o ingreso un valor negativo o cero, **cuando** intento guardar, **entonces** el sistema no lo permite y muestra un mensaje de error.

**HU-07 · Uso sin conexión** · Prioridad: Must

Como usuario, quiero registrar y consultar mis movimientos, aunque no tenga internet, para no depender de la conexión.

Criterios de aceptación:

- **Dado** que no tengo conexión, **cuando** registro un movimiento, **entonces** se guarda en el dispositivo y queda marcado como pendiente de sincronizar.
- **Dado** que recupero la conexión, **cuando** la aplicación lo detecta, **entonces** sincroniza automáticamente los movimientos pendientes.
- **Dado** que un movimiento ya fue sincronizado, **cuando** se vuelve a ejecutar la sincronización, **entonces** no se crea un registro duplicado.

**Módulo de presupuestos y reportes**

**HU-08 · Alertas de presupuesto** · Prioridad: Must

Como usuario, quiero recibir una alerta cuando esté cerca del límite de una categoría, para ajustar mis gastos antes de terminar el mes.

Criterios de aceptación:

- **Dado** que una categoría tiene presupuesto definido, **cuando** el gasto acumulado alcanza el 75% del límite, **entonces** la pantalla de inicio muestra una alerta con el porcentaje usado y el monto restante.
- **Dado** que activé las notificaciones, **cuando** se genera una alerta, **entonces** recibo una notificación en el celular.

**HU-09 · Reporte de gastos por categoría** · Prioridad: Must

Como usuario, quiero ver mis gastos del mes agrupados por categoría y comparados con el mes anterior, para identificar en qué estoy gastando de más.

Criterios de aceptación:

- **Dado** que tengo movimientos registrados en el mes, **cuando** entro a Reportes, **entonces** veo el total gastado y un gráfico con el porcentaje de cada categoría.
- **Dado** que tengo datos del mes anterior, **cuando** reviso la comparación, **entonces** los aumentos se muestran en rojo y las reducciones en verde.
- **Dado** que no tengo movimientos en el mes, **cuando** entro a Reportes, **entonces** veo un mensaje que me invita a registrar mi primer gasto.

**Módulo de simulador**

**HU-10 · Simulación de ahorro** · Prioridad: Should

Como usuario, quiero proyectar cuánto ahorraría en varios años según mi ritmo actual, para motivarme a mantener o aumentar mi ahorro.

Criterios de aceptación:

- **Dado** que tengo al menos un mes de movimientos, **cuando** entro al simulador, **entonces** veo mi ahorro promedio mensual calculado a partir de mis datos reales.
- **Dado** que muevo el horizonte de tiempo, **cuando** cambio el número de años, **entonces** los valores con y sin interés se recalculan de inmediato.
- **Dado** que aumento el aporte mensual, **cuando** veo la sugerencia, **entonces** se muestra cuánto dinero adicional acumularía en el horizonte elegido.
- **Dado** que veo la simulación, **cuando** reviso los resultados, **entonces** se indica que la tasa es estimada y que no constituye asesoría financiera.

Las funcionalidades previstas para versiones futuras, como el inicio de sesión con Google y Apple o las metas de ahorro, se clasifican como **Won't** en esta etapa y se detallan en la sección 4.2. Cada historia de usuario se traduce en uno o más requisitos funcionales en la sección 4.3, lo que permite rastrear cada requisito hasta la necesidad del usuario que lo originó.
