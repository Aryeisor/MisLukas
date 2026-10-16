-- =============================================================================
-- MisLukas · Fase 5B · 002: categorías
-- Las predeterminadas son filas globales con usuario_id null (docs/06 §6.4.1,
-- docs/08 §8.5.2): todos las leen y nadie las modifica. Sus UUID son los de
-- DefaultCategory (lib/features/budgets/domain/entities/default_categories.dart)
-- y no se deben cambiar nunca.
-- =============================================================================

begin;

create table if not exists public.categorias (
  id uuid primary key,
  -- Null solo en las predeterminadas. Las políticas impiden escribir null.
  usuario_id uuid default auth.uid() references auth.users (id) on delete cascade,
  nombre text not null
    constraint categorias_nombre_check check (char_length(nombre) between 1 and 60),
  tipo text not null
    constraint categorias_tipo_check check (tipo in ('gasto', 'ingreso')),
  icono text
    constraint categorias_icono_check check (char_length(icono) <= 40),
  color text
    constraint categorias_color_check check (char_length(color) <= 20),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  eliminado_en timestamptz,
  sincronizado_en timestamptz not null default now()
);

-- Pull de la Fase 5C: "lo mío modificado desde X".
create index if not exists categorias_usuario_sincronizado_idx
  on public.categorias (usuario_id, sincronizado_en);

create or replace trigger categorias_asignar_sincronizado_en
  before insert or update on public.categorias
  for each row execute function public.asignar_sincronizado_en();

-- Categorías predeterminadas: mismos UUID, nombres, tipo, icono y fecha de
-- creación que la base local (defaultCategoriesCreatedAt = 2026-01-01 UTC).
insert into public.categorias (id, usuario_id, nombre, tipo, icono, creado_en, actualizado_en)
values
  ('2909b516-0ab3-493e-b8e8-90f8ccf28aed', null, 'Mercado',      'gasto',   'mercado',      '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('3a406a70-09bd-4b1e-b945-1b2600f5bb12', null, 'Transporte',   'gasto',   'transporte',   '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('69f498cd-1f9f-4c86-bcb5-166d76cec417', null, 'Ocio',         'gasto',   'ocio',         '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('cabdf6bb-527d-477d-a489-bad388d5c482', null, 'Servicios',    'gasto',   'servicios',    '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('36b145c6-2ea6-4067-b264-5d69270f0367', null, 'Restaurantes', 'gasto',   'restaurantes', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('14ba8c36-dfee-4253-ab2e-13ac6ef7ebd0', null, 'Otros',        'gasto',   'otros',        '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('7d4c2cae-fe7f-4353-80ac-2947009b026d', null, 'Ingreso',      'ingreso', 'ingreso',      '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')
on conflict (id) do nothing;

-- Seguridad ------------------------------------------------------------------

alter table public.categorias enable row level security;

drop policy if exists categorias_select on public.categorias;
create policy categorias_select on public.categorias
  for select to authenticated
  using (usuario_id is null or (select auth.uid()) = usuario_id);

drop policy if exists categorias_insert_propias on public.categorias;
create policy categorias_insert_propias on public.categorias
  for insert to authenticated
  with check ((select auth.uid()) = usuario_id);

drop policy if exists categorias_update_propias on public.categorias;
create policy categorias_update_propias on public.categorias
  for update to authenticated
  using ((select auth.uid()) = usuario_id)
  with check ((select auth.uid()) = usuario_id);

-- Sin política ni permiso de delete: el borrado es lógico (eliminado_en).
revoke all on table public.categorias from anon, authenticated;
grant select, insert, update on table public.categorias to authenticated;

commit;
