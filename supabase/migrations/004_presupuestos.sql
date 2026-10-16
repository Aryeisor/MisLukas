-- =============================================================================
-- MisLukas · Fase 5B · 004: presupuestos
-- =============================================================================

begin;

create table if not exists public.presupuestos (
  id uuid primary key,
  usuario_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  categoria_id uuid not null references public.categorias (id),
  -- Primer día del mes.
  mes date not null
    constraint presupuestos_mes_check check (extract(day from mes) = 1),
  monto_limite bigint not null
    constraint presupuestos_monto_limite_check check (monto_limite > 0),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  eliminado_en timestamptz,
  sincronizado_en timestamptz not null default now()
);

-- Un presupuesto activo por usuario, categoría y mes. Es parcial para que,
-- tras eliminar uno (borrado lógico), se pueda crear otro con un id nuevo.
create unique index if not exists presupuestos_categoria_mes_activo_key
  on public.presupuestos (usuario_id, categoria_id, mes)
  where eliminado_en is null;

create index if not exists presupuestos_usuario_sincronizado_idx
  on public.presupuestos (usuario_id, sincronizado_en);

create or replace trigger presupuestos_asignar_sincronizado_en
  before insert or update on public.presupuestos
  for each row execute function public.asignar_sincronizado_en();

create or replace trigger presupuestos_validar_categoria
  before insert or update of categoria_id, usuario_id on public.presupuestos
  for each row execute function public.validar_categoria_del_usuario();

-- Seguridad ------------------------------------------------------------------

alter table public.presupuestos enable row level security;

drop policy if exists presupuestos_select_propios on public.presupuestos;
create policy presupuestos_select_propios on public.presupuestos
  for select to authenticated
  using ((select auth.uid()) = usuario_id);

drop policy if exists presupuestos_insert_propios on public.presupuestos;
create policy presupuestos_insert_propios on public.presupuestos
  for insert to authenticated
  with check ((select auth.uid()) = usuario_id);

drop policy if exists presupuestos_update_propios on public.presupuestos;
create policy presupuestos_update_propios on public.presupuestos
  for update to authenticated
  using ((select auth.uid()) = usuario_id)
  with check ((select auth.uid()) = usuario_id);

revoke all on table public.presupuestos from anon, authenticated;
grant select, insert, update on table public.presupuestos to authenticated;

commit;
