-- =============================================================================
-- MisLukas · Fase 5B · Deshacer las migraciones 001 a 008
--
-- SOLO PARA DESARROLLO. Borra las tablas de la Fase 5B con todos sus datos
-- (perfiles, categorías, movimientos, presupuestos y recibos) para volver a
-- ejecutar las migraciones desde cero. No toca auth.users: las cuentas siguen
-- existiendo y la migración 006 les vuelve a crear el perfil.
--
-- El bucket "recibos" no se borra desde SQL (Storage no permite borrar sus
-- tablas directamente). Si hace falta, vacíalo y elimínalo en el panel:
-- Storage > recibos > Delete bucket. La migración 007 lo recrea o lo
-- actualiza sin error si todavía existe.
-- =============================================================================

begin;

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

-- 001
drop function if exists public.validar_categoria_del_usuario();
drop function if exists public.asignar_actualizado_en();
drop function if exists public.asignar_sincronizado_en();

commit;
