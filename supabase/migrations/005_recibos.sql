-- =============================================================================
-- MisLukas · Fase 5B · 005: recibos
-- La ruta local de la imagen no sale del dispositivo. ruta_storage solo existe
-- si el usuario respalda sus recibos (Fase 6): {usuario_id}/{id}.jpg en el
-- bucket privado "recibos" (migración 007).
-- =============================================================================

begin;

create table if not exists public.recibos (
  id uuid primary key,
  usuario_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  movimiento_id uuid not null,
  ruta_storage text,
  total_detectado bigint
    constraint recibos_total_detectado_check check (total_detectado > 0),
  comercio_detectado text
    constraint recibos_comercio_detectado_check check (char_length(comercio_detectado) <= 200),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  eliminado_en timestamptz,
  sincronizado_en timestamptz not null default now(),
  -- La imagen respaldada debe estar en la carpeta del dueño del recibo.
  constraint recibos_ruta_storage_check check (
    char_length(ruta_storage) <= 200
    and starts_with(ruta_storage, usuario_id::text || '/')
  ),
  -- Compuesta: el movimiento debe ser del mismo usuario que el recibo.
  constraint recibos_movimiento_fkey foreign key (usuario_id, movimiento_id)
    references public.movimientos (usuario_id, id)
);

-- Un recibo activo por movimiento; los eliminados no cuentan. Incluye
-- usuario_id para que el recibo de otro usuario no choque con este índice
-- (23505) y lo rechace la llave foránea compuesta (23503): así el código de
-- error no revela si un movimiento ajeno existe (ver 008).
create unique index if not exists recibos_usuario_movimiento_activo_key
  on public.recibos (usuario_id, movimiento_id)
  where eliminado_en is null;

create index if not exists recibos_usuario_sincronizado_idx
  on public.recibos (usuario_id, sincronizado_en);

create or replace trigger recibos_asignar_sincronizado_en
  before insert or update on public.recibos
  for each row execute function public.asignar_sincronizado_en();

-- Seguridad ------------------------------------------------------------------

alter table public.recibos enable row level security;

drop policy if exists recibos_select_propios on public.recibos;
create policy recibos_select_propios on public.recibos
  for select to authenticated
  using ((select auth.uid()) = usuario_id);

drop policy if exists recibos_insert_propios on public.recibos;
create policy recibos_insert_propios on public.recibos
  for insert to authenticated
  with check ((select auth.uid()) = usuario_id);

drop policy if exists recibos_update_propios on public.recibos;
create policy recibos_update_propios on public.recibos
  for update to authenticated
  using ((select auth.uid()) = usuario_id)
  with check ((select auth.uid()) = usuario_id);

revoke all on table public.recibos from anon, authenticated;
grant select, insert, update on table public.recibos to authenticated;

commit;
