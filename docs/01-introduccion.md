# Introducción

MisLukas es una aplicación móvil de finanzas personales pensada para que cualquier persona sepa, en pocos segundos, cuánto dinero tiene disponible en el mes, en qué lo está gastando y cuánto podría ahorrar si mantiene o mejora sus hábitos. El nombre viene de "lukas", la forma coloquial en que en Colombia nos referimos a los miles de pesos. Elegimos ese nombre porque queríamos que la app hablara el mismo idioma de sus usuarios y se sintiera cercana, no como una herramienta bancaria fría.

La aplicación gira alrededor de tres acciones: registrar, entender y proyectar. Registrar un gasto debe ser tan rápido como tomarle una foto al recibo; la app extrae el valor y sugiere la categoría, y el usuario solo confirma. Entender significa ver sus gastos agrupados por categoría y compararlos con el mes anterior, para detectar dónde se está yendo la plata. Proyectar es la parte que menos ofrecen las herramientas tradicionales: a partir del ahorro real de los últimos meses, el simulador muestra cuánto acumularía la persona en uno o varios años, con y sin rendimientos.

Desde el punto de vista técnico, MisLukas es una aplicación multiplataforma desarrollada en Flutter, con una base de datos local en el dispositivo que le permite funcionar sin conexión a internet, y un backend en Supabase que se encarga de la autenticación, la autorización y el respaldo de la información en la nube. Como maneja datos financieros, la seguridad es un requisito central del diseño y no un agregado posterior; esto se desarrolla en detalle en la sección 8.

# 1. Propósito del documento

Este documento describe el diseño de MisLukas en su etapa de producto mínimo viable (MVP). Su objetivo es explicar qué problema resuelve la aplicación, a quién está dirigida, cómo se ve y cómo funciona por dentro, de manera que cualquier persona del equipo, el docente o un desarrollador externo pueda entender el proyecto sin necesidad de explicaciones adicionales.

Además de describir, el documento busca justificar. En cada sección explicamos por qué elegimos una tecnología, un patrón de diseño o una medida de seguridad, y qué alternativas descartamos. Consideramos que un documento de diseño es útil cuando permite revisar las decisiones con criterio, no solo cuando las enumera.

Por último, el documento sirve como guía para la fase de desarrollo y despliegue. Los requisitos, el modelo de datos y la arquitectura aquí definidos son el punto de partida para construir la aplicación en Flutter y publicarla en las tiendas de aplicaciones.

## 1.1 Alcance del MVP

Un MVP es la versión más pequeña de un producto que permite validar su idea central con usuarios reales. En el caso de MisLukas, la idea que queremos validar es que registrar gastos con una foto y ver proyecciones de ahorro hace que las personas controlen mejor su dinero y no abandonen la aplicación a las pocas semanas, como suele pasar con este tipo de herramientas. Por eso el MVP se concentra en el ciclo completo de registrar, entender y proyectar, y deja para después las funciones que no aportan a esa validación.

**El MVP incluye:**

Registro de usuario e inicio de sesión con correo y contraseña, junto con la recuperación de contraseña.

Pantalla de inicio con el disponible del mes, alertas de presupuesto y últimos movimientos.

Registro de gastos por foto del recibo, con extracción automática del valor y sugerencia de categoría, o de forma manual.

Reportes de gastos por categoría y comparación con el mes anterior.

Simulador de ahorro con horizonte de tiempo ajustable y escenarios con y sin interés.

Funcionamiento sin conexión, con sincronización automática cuando el dispositivo recupera internet.

Medidas de seguridad en autenticación, autorización y almacenamiento local de datos.

**Queda fuera del MVP:**

Inicio de sesión con Google y Apple.

Autenticación en dos pasos (2FA).

Metas de ahorro personalizadas.

Manejo de varias cuentas o billeteras.

Conexión directa con bancos.

Exportación de reportes.

Pantalla de perfil completa, que se diseña en la siguiente iteración.

Estas funciones no se descartan: están contempladas en la arquitectura para que puedan agregarse sin rehacer lo construido
