-- =============================================================================
-- MisLukas · Fases 5B y 5C · Deshacer las migraciones 001 a 009
--
-- SOLO PARA DESARROLLO. Borra las tablas de la Fase 5B con todos sus datos
-- (perfiles, categorías, movimientos, presupuestos y recibos) y lo agregado en
-- la 5C (009), para volver a ejecutar las migraciones desde cero. No toca
-- auth.users: las cuentas siguen existiendo y la migración 006 les vuelve a
-- crear el perfil.
--
-- El bucket "recibos" no se borra desde SQL (Storage no permite borrar sus
-- tablas directamente). Si hace falta, vacíalo y elimínalo en el panel:
-- Storage > recibos > Delete bucket. La migración 007 lo recrea o lo
-- actualiza sin error si todavía existe.
-- =============================================================================

begin;

-- 009 (los triggers de última escritura se borran con sus tablas)
drop function if exists public.eliminar_mi_cuenta();
drop policy if exists recibos_storage_delete_propios on storage.objects;

-- 007
drop policy if exists recibos_storage_select_propios on storage.objects;
drop policy if exists recibos_storage_insert_propios on storage.objects;
drop policy if exists recibos_storage_update_propios on storage.objects;

-- 006
drop trigger if exists crear_perfil_al_registrarse on auth.users;
drop table if exists public.perfiles;
drop function if exists public.crear_perfil_de_usuario();

-- 008 y 005 a 002, en orden inverso por las llaves foráneas (los índices
-- se borran con su tabla)
drop table if exists public.recibos;
drop table if exists public.presupuestos;
drop table if exists public.movimientos;
drop table if exists public.categorias;
drop function if exists public.conservar_ultima_escritura();

-- 001
drop function if exists public.validar_categoria_del_usuario();
drop function if exists public.asignar_actualizado_en();
drop function if exists public.asignar_sincronizado_en();

commit;
