-- =============================================================================
-- MisLukas · Fase 5C · 009: sincronización y eliminación de la cuenta
--
-- 1. La última escritura gana y la eliminación prevalece, también en el
--    servidor (docs/06 §6.6.3).
-- 2. Política de delete en el bucket recibos: el usuario borra sus archivos
--    antes de eliminar su cuenta.
-- 3. eliminar_mi_cuenta(): borra al usuario que llama y, en cascada, todos sus
--    datos (docs/08 §8.9.4, Ley 1581).
--
-- Repetible: se puede ejecutar más de una vez.
-- =============================================================================

begin;

-- 1. Última escritura gana ----------------------------------------------------
--
-- La app envía primero sus cambios y después recibe (docs/06 §6.6.2). Sin
-- este trigger, un celular que estuvo sin conexión pisaría en el servidor una
-- edición más reciente hecha en otro dispositivo, y ese otro dispositivo
-- recibiría después la versión vieja.
--
-- Devolver null en un trigger BEFORE UPDATE deja la fila como estaba, también
-- en el upsert de PostgREST (insert ... on conflict do update): la solicitud
-- responde bien y la app recibe en el pull la versión que quedó.
--
-- La comparación usa actualizado_en, que es la hora del dispositivo que
-- escribió (limitación conocida, docs/06 §6.6.3).
create or replace function public.conservar_ultima_escritura()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  -- La eliminación prevalece: un registro eliminado no revive ni cambia.
  if old.eliminado_en is not null then
    return null;
  end if;
  -- Una eliminación se acepta aunque sea más vieja que la última edición.
  if new.eliminado_en is not null then
    return new;
  end if;
  -- Una versión más vieja que la guardada no la reemplaza.
  if new.actualizado_en < old.actualizado_en then
    return null;
  end if;
  return new;
end;
$$;

revoke execute on function public.conservar_ultima_escritura() from public, anon, authenticated;

-- Los triggers del mismo evento se ejecutan en orden alfabético: el prefijo
-- "0" hace que este vaya antes que los de 5B.
create or replace trigger categorias_0_conservar_ultima_escritura
  before update on public.categorias
  for each row execute function public.conservar_ultima_escritura();

create or replace trigger movimientos_0_conservar_ultima_escritura
  before update on public.movimientos
  for each row execute function public.conservar_ultima_escritura();

create or replace trigger presupuestos_0_conservar_ultima_escritura
  before update on public.presupuestos
  for each row execute function public.conservar_ultima_escritura();

create or replace trigger recibos_0_conservar_ultima_escritura
  before update on public.recibos
  for each row execute function public.conservar_ultima_escritura();

-- 2. Borrar archivos propios en Storage --------------------------------------
--
-- Supabase no permite borrar archivos de Storage con SQL: la app los borra
-- con la API de Storage antes de llamar a eliminar_mi_cuenta(). Misma
-- condición que las políticas de 007: carpeta propia y sin subcarpetas.

drop policy if exists recibos_storage_delete_propios on storage.objects;
create policy recibos_storage_delete_propios on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'recibos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and array_length(storage.foldername(name), 1) = 1
  );

-- 3. Eliminar la cuenta ------------------------------------------------------
--
-- SECURITY DEFINER: authenticated no tiene permisos sobre auth.users. Solo
-- borra al usuario del token (auth.uid()); no recibe parámetros. El cascade
-- de las llaves foráneas borra perfiles, movimientos, presupuestos, recibos y
-- categorías personalizadas, y las sesiones del usuario en auth.
--
-- Equivalente en el servidor de pedir la contraseña: exige que el token venga
-- de una verificación con contraseña de hace menos de 5 minutos (claim amr del
-- JWT, que la app renueva con signInWithPassword justo antes).
--
-- Los errores usan el código P0001 con una pista (hint) fija para que la app
-- los distinga sin leer el mensaje.
create or replace function public.eliminar_mi_cuenta()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_password_at bigint;
begin
  if v_uid is null then
    raise exception 'Sin sesión' using errcode = '42501';
  end if;

  select max((m ->> 'timestamp')::bigint) into v_password_at
  from jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) as m
  where m ->> 'method' = 'password';

  if v_password_at is null
     or v_password_at < extract(epoch from now())::bigint - 300 then
    raise exception 'Hay que verificar la contraseña de nuevo'
      using errcode = 'P0001', hint = 'reautenticacion';
  end if;

  -- Sin archivos huérfanos: deben borrarse antes con la API de Storage.
  if exists (
    select 1 from storage.objects o
    where o.bucket_id = 'recibos'
      and (storage.foldername(o.name))[1] = v_uid::text
  ) then
    raise exception 'Quedan archivos del usuario en Storage'
      using errcode = 'P0001', hint = 'archivos_pendientes';
  end if;

  delete from auth.users where id = v_uid;
end;
$$;

revoke execute on function public.eliminar_mi_cuenta() from public, anon;
grant execute on function public.eliminar_mi_cuenta() to authenticated;

commit;
