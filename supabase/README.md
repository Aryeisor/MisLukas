# Esquema remoto de MisLukas (Supabase)

Scripts SQL del servidor, versionados junto con la app (docs/06 §6.3.2). Se ejecutan a mano en el **SQL Editor** del panel de Supabase, sin CLI ni Docker.

## Migraciones

Ejecútalas una sola vez, **en este orden**. Cada una depende de las anteriores.

| Orden | Archivo | Qué crea |
| --- | --- | --- |
| 1 | `migrations/001_funciones_comunes.sql` | Funciones de los triggers (`sincronizado_en`, `actualizado_en`, pertenencia de la categoría) |
| 2 | `migrations/002_categorias.sql` | Tabla `categorias`, las 7 predeterminadas, RLS y permisos |
| 3 | `migrations/003_movimientos.sql` | Tabla `movimientos`, RLS y permisos |
| 4 | `migrations/004_presupuestos.sql` | Tabla `presupuestos`, RLS y permisos |
| 5 | `migrations/005_recibos.sql` | Tabla `recibos`, RLS y permisos |
| 6 | `migrations/006_perfiles.sql` | Tabla `perfiles`, trigger de registro en `auth.users` y perfiles de las cuentas existentes |
| 7 | `migrations/007_storage_recibos.sql` | Bucket privado `recibos` y sus políticas |
| 8 | `migrations/008_recibos_indice_por_usuario.sql` | Cambia la unicidad de recibos a (usuario_id, movimiento_id), para que el error al usar un movimiento ajeno no revele si existe |
| 9 | `migrations/009_sincronizacion_y_cuenta.sql` | Fase 5C: la última escritura gana y la eliminación prevalece (trigger en las 4 tablas), política de delete en el bucket `recibos` y la función `eliminar_mi_cuenta()` |

En una instalación desde cero, la 005 ya crea el índice nuevo y la 008 no cambia nada. Igual hay que ejecutarla: es la que corrige las bases donde se ejecutó la versión anterior de la 005.

Para cada archivo:

1. SQL Editor → **New query**.
2. Pega el contenido completo del archivo.
3. Pulsa **Run**.
4. Debe aparecer **"Success. No rows returned"**.

Si el editor pregunta por una operación destructiva ("destructive operation"), es por los `drop policy if exists` / `revoke` que dejan los archivos repetibles. Confirma.

## Si un archivo falla

Cada archivo está envuelto en `begin; … commit;`. Si una sentencia falla, PostgreSQL aborta la transacción completa y **no queda nada aplicado de ese archivo**. Los archivos anteriores, ya confirmados, siguen intactos.

1. Lee el error. Indica la sentencia y la línea.
2. Corrige la causa (por ejemplo, ejecutaste el 003 sin haber ejecutado el 002).
3. Vuelve a ejecutar **el mismo archivo completo**. No hace falta deshacer nada.

Los archivos además son repetibles (`if not exists`, `create or replace`, `drop policy if exists`, `on conflict`): ejecutar dos veces uno que ya funcionó no da error ni duplica datos.

**Si el estado quedó confuso** (por ejemplo, se ejecutó una versión anterior de un archivo, o un trozo suelto seleccionado a mano fuera de la transacción):

1. Ejecuta `rollback_5b.sql`. Borra todo lo de la 5B y la 009, incluidos los datos de esas tablas. Es **solo para desarrollo**.
2. Vuelve a ejecutar las migraciones desde la 001.

## Verificación

Ejecuta `verify.sql` completo (pégalo y pulsa Run). El resultado es una tabla con columnas `#`, `prueba` y `resultado`: **todas las filas deben decir `OK`**. Una fila `FALLO: …` incluye el código de error de PostgreSQL y el mensaje.

`verify.sql` crea tres usuarios temporales (A, B y C) y datos de prueba, y al final lo revierte todo: no deja usuarios, filas ni archivos. C prueba la eliminación de la cuenta con `eliminar_mi_cuenta()`; el token se simula con el claim `amr` (contraseña verificada hace poco).

La primera parte del archivo trae listados para revisar a mano: RLS por tabla, políticas, permisos y usuarios sin perfil. Para ver uno, selecciónalo en el editor y ejecuta solo esa selección.
