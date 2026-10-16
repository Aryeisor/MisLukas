-- =============================================================================
-- MisLukas · Fase 5B · 003: movimientos
-- =============================================================================

begin;

create table if not exists public.movimientos (
  id uuid primary key,
  usuario_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  categoria_id uuid not null references public.categorias (id),
  -- Para agregar un tipo (por ejemplo 'saldo_inicial') basta una migración:
  --   alter table public.movimientos
  --     drop constraint movimientos_tipo_check,
  --     add constraint movimientos_tipo_check
  --       check (tipo in ('gasto', 'ingreso', 'saldo_inicial'));
  tipo text not null
    constraint movimientos_tipo_check check (tipo in ('gasto', 'ingreso')),
  -- Pesos colombianos sin decimales.
  monto bigint not null
    constraint movimientos_monto_check check (monto > 0),
  fecha date not null,
  -- Mismos límites que la app (movementTextMaxLength = 200).
  descripcion text not null
    constraint movimientos_descripcion_check check (char_length(descripcion) between 1 and 200),
  nota text
    constraint movimientos_nota_check check (char_length(nota) <= 200),
  origen text not null
    constraint movimientos_origen_check check (origen in ('foto', 'manual')),
  cuenta text not null default 'principal'
    constraint movimientos_cuenta_check check (char_length(cuenta) between 1 and 40),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  eliminado_en timestamptz,
  sincronizado_en timestamptz not null default now(),
  -- Destino de la llave foránea compuesta de recibos: un recibo solo puede
  -- apuntar a un movimiento del mismo usuario. PostgreSQL exige una
  -- restricción única total (no parcial) como destino; como id ya es la llave
  -- primaria, nunca bloquea nada adicional.
  constraint movimientos_usuario_id_id_key unique (usuario_id, id)
);

create index if not exists movimientos_usuario_sincronizado_idx
  on public.movimientos (usuario_id, sincronizado_en);

create or replace trigger movimientos_asignar_sincronizado_en
  before insert or update on public.movimientos
  for each row execute function public.asignar_sincronizado_en();

create or replace trigger movimientos_validar_categoria
  before insert or update of categoria_id, usuario_id on public.movimientos
  for each row execute function public.validar_categoria_del_usuario();

-- Seguridad ------------------------------------------------------------------

alter table public.movimientos enable row level security;

drop policy if exists movimientos_select_propios on public.movimientos;
create policy movimientos_select_propios on public.movimientos
  for select to authenticated
  using ((select auth.uid()) = usuario_id);

drop policy if exists movimientos_insert_propios on public.movimientos;
create policy movimientos_insert_propios on public.movimientos
  for insert to authenticated
  with check ((select auth.uid()) = usuario_id);

drop policy if exists movimientos_update_propios on public.movimientos;
create policy movimientos_update_propios on public.movimientos
  for update to authenticated
  using ((select auth.uid()) = usuario_id)
  with check ((select auth.uid()) = usuario_id);

revoke all on table public.movimientos from anon, authenticated;
grant select, insert, update on table public.movimientos to authenticated;

commit;
