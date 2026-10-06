# 2. Problema y Justificación

El manejo del dinero personal es un tema en el que casi todos creemos tener control, hasta que llega el final del mes y la cuenta no cuadra. MisLukas parte de tres problemas concretos que se refuerzan entre sí.

**Las personas no saben en qué gastan**

Tener un plan para el dinero no es lo mismo que saber en qué se fue. Una encuesta nacional sobre capacidades financieras publicada por el Banco Mundial lo muestra con claridad: aunque el 94% de los colombianos dijo planificar su presupuesto, solo el 23% sabía exactamente cuánto había gastado la semana anterior. La misma encuesta encontró que el 65% de la población manifestó no tener suficiente dinero para cubrir sus gastos básicos, de forma habitual u ocasional, y que apenas 1 de cada 5 personas podría afrontar un gasto importante imprevisto. (Mundial, s.f.).

**Registrar gastos a mano es tedioso y se abandona**

La solución obvia al problema anterior es anotar cada gasto, pero en la práctica pocas personas lo sostienen. Llevar una libreta, una hoja de cálculo o incluso una app de registro manual exige detenerse después de cada compra, recordar el valor exacto y clasificarlo. El esfuerzo es pequeño cada vez, pero constante, y basta con olvidar unos días para que el registro pierda sentido y se abandone.

Este es el punto en el que fallan muchas herramientas: están bien diseñadas para analizar datos, pero no para capturarlos. Si registrar un gasto toma más tiempo o atención de lo que el usuario está dispuesto a dar en el momento de pagar, la aplicación deja de usarse, sin importar qué tan buenos sean sus reportes.

**No se visualiza el efecto del ahorro a futuro**

El tercer problema es de motivación. Ahorrar \$50.000 o \$100.000 al mes parece poco significativo cuando se mira mes a mes, y por eso es fácil posponerlo. Lo que casi nunca se ve es el efecto acumulado de ese hábito en uno, tres o cinco años, ni la diferencia que hace que ese dinero genere rendimientos. La encuesta del Banco Mundial también encontró que el 88% de los colombianos expresó preocupación por gastos futuros como la jubilación, pero solo el 41% tenía planes para cubrirlos por completo. Existe la preocupación, pero falta una herramienta que convierta el ahorro de hoy en una cifra concreta de mañana. (Mundial, s.f.).

## 2.1 Cómo lo resuelve MisLukas

MisLukas aborda cada uno de estos problemas con una funcionalidad específica, pensada para que el usuario obtenga valor desde el primer día sin tener que cambiar radicalmente sus hábitos.

| Problema                            | Solución en MisLukas                                         | Pantalla                        |
| ----------------------------------- | ------------------------------------------------------------ | ------------------------------- |
| No se sabe en qué se gasta          | Reportes por categoría y comparación con el mes anterior     | Reportes                        |
| Registrar es tedioso                | Registro por foto del recibo con valor y categoría sugeridos | Nuevo gasto, Confirma los datos |
| Se pierde el control durante el mes | Alertas de presupuesto por categoría                         | Inicio                          |
| No se ve el efecto del ahorro       | Simulador de ahorro con y sin interés                        | Simulador                       |

**Registro rápido por foto del recibo.** Es la respuesta directa al abandono del registro manual. El usuario toma una foto del recibo y la aplicación, mediante reconocimiento de texto en el propio dispositivo, extrae el valor total y sugiere una categoría según el comercio. El usuario solo revisa y confirma. El objetivo de diseño es que registrar un gasto tome menos de quince segundos. Para los gastos sin recibo, como un pasaje o una compra en efectivo, se mantiene el registro manual, reducido a lo mínimo: valor y categoría.

**Alertas de presupuesto.** Saber en qué se gastó al final del mes sirve para aprender, pero no para corregir a tiempo. Por eso la pantalla de inicio muestra alertas cuando una categoría se acerca a su límite, por ejemplo "Presupuesto de mercado al 78%", junto con lo que queda disponible hasta fin de mes. La alerta llega mientras todavía es posible ajustar el gasto.

**Reportes comparativos.** La pantalla de reportes agrupa los gastos del mes por categoría en un gráfico de dona y los compara con el mes anterior, marcando en rojo los aumentos y en verde las reducciones. Así el usuario no solo ve cuánto gastó, sino si está mejorando o empeorando, y en qué categoría específica.

**Simulador de ahorro.** Toma el promedio de ahorro real del usuario en los últimos tres meses y lo proyecta en un horizonte de uno a diez años, mostrando el resultado sin interés y con un rendimiento estimado. También plantea escenarios como "¿y si ahorras \$50.000 más al mes?". La idea es convertir una decisión pequeña de hoy en una cifra concreta a futuro, que es lo que suele faltar para motivar el ahorro.

## 2.2 Diferenciador

Existen muchas aplicaciones de finanzas personales. MisLukas no pretende competir en cantidad de funciones, sino en cuatro aspectos concretos que consideramos poco atendidos por las alternativas disponibles.

**Contexto colombiano.** La aplicación está pensada desde el inicio para Colombia: montos en pesos con el formato local, categorías y ejemplos basados en comercios y servicios cotidianos del país, y un lenguaje cercano, empezando por el propio nombre. Las aplicaciones globales suelen soportar el peso colombiano como una moneda más, pero su diseño, sus categorías y su lenguaje responden a otros mercados.

**Menos fricción al registrar.** Mientras muchas aplicaciones centran su propuesta en el análisis, MisLukas pone el foco en el momento de captura, que es donde se abandona el hábito. El registro por foto con categoría sugerida es la funcionalidad principal del MVP, no un agregado.

**Funciona sin internet.** Toda la información se guarda primero en el dispositivo y se sincroniza cuando hay conexión. El usuario puede registrar un gasto en el bus, en un sótano o con los datos agotados, y la aplicación responde igual de rápido. En un contexto donde la conexión móvil no siempre es estable ni ilimitada, esto no es un detalle menor.

**Protección de datos sensibles.** La información financiera revela hábitos, ingresos y lugares frecuentados. MisLukas no pide conectar cuentas bancarias, cifra la base de datos local, protege el acceso con biometría o PIN y restringe en el servidor que cada usuario solo acceda a su propia información. La sección 8 desarrolla estas medidas.

## 2.3 Análisis de aplicaciones similares

Para ubicar a MisLukas frente a lo que ya existe, comparamos tres aplicaciones con enfoques distintos: una aplicación global con conexión bancaria (Wallet), una aplicación de registro manual simple (Monefy) y una billetera digital colombiana con herramientas de ahorro (Nequi).

**Wallet (BudgetBakers)** es una aplicación de finanzas personales de alcance internacional. Su versión móvil ofrece notificaciones en tiempo real, registro rápido de gastos, escaneo de recibos y modo sin conexión. Su funcionalidad más destacada es la conexión con bancos, aunque la sincronización bancaria es una función premium. Una reseña de 2026 señala que la versión gratuita permite registrar manualmente y ver reportes básicos, mientras que la sincronización bancaria, los presupuestos avanzados y los reportes más útiles quedan reservados para usuarios de pago, con un costo aproximado de 4,49 euros al mes. (BudgetBakers, s.f.).

**Monefy** apuesta por la simplicidad. Permite introducir los gastos diarios de forma manual, distribuyéndolos en categorías, sin necesidad de vincular una cuenta bancaria. Entre sus funciones están la sincronización mediante la cuenta de Google Drive o Dropbox del usuario, los pagos recurrentes, el uso de varias divisas y la protección con contraseña. Su fortaleza es la rapidez del registro manual, pero no ofrece captura por foto ni proyecciones de ahorro. (Coomeva, s.f.).

**Nequi** no es una aplicación de control de gastos como tal, sino una billetera digital de Bancolombia muy usada en el país. Incluye herramientas de ahorro como el Colchón, para guardar dinero y evitar la tentación de gastarlo; las Metas de ahorro, para objetivos concretos; y los Bolsillos, para separar la plata de cada obligación. Su limitación, desde la perspectiva de este proyecto, es que solo organiza el dinero que está dentro de Nequi; los gastos en efectivo o con otros medios de pago quedan por fuera. (Nequi, s.f.).
