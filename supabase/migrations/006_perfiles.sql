-- =============================================================================
-- MisLukas · Fase 5B · 006: perfiles
-- Se crea con un trigger al registrarse (auth.users). Guarda el nombre y la
-- versión de la política de tratamiento de datos aceptada, con su fecha, para
-- poder demostrar la autorización (docs/08 §8.9.1, Ley 1581). Su id es el del
-- usuario (docs/08 §8.5.2), por eso no lleva usuario_id.
-- =============================================================================

begin;

create table if not exists public.perfiles (
  id uuid primary key references auth.users (id) on delete cascade,
  -- Mismo límite que la app (nameMaxLength = 60).
  nombre text not null
    constraint perfiles_nombre_check check (char_length(nombre) between 1 and 60),
  politica_version text not null
    constraint perfiles_politica_version_check check (char_length(politica_version) between 1 and 20),
  politica_aceptada_en timestamptz not null default now(),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create or replace trigger perfiles_asignar_actualizado_en
  before update on public.perfiles
  for each row execute function public.asignar_actualizado_en();

-- Crea el perfil al registrarse. SECURITY DEFINER es necesario: la ejecuta
-- supabase_auth_admin, que no tiene permisos sobre public.perfiles. Solo
-- escribe la fila del usuario que se está creando (new.id).
create or replace function public.crear_perfil_de_usuario()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nombre text := btrim(coalesce(new.raw_user_meta_data ->> 'nombre', ''));
  v_politica text := btrim(coalesce(new.raw_user_meta_data ->> 'politica_version', ''));
begin
  -- Equivalente en el servidor de la casilla de aceptación: sin versión de la
  -- política no hay registro.
  if v_politica = '' then
    raise exception 'Falta la aceptación de la política de tratamiento de datos'
      using errcode = '23514';
  end if;

  insert into public.perfiles (id, nombre, politica_version, politica_aceptada_en)
  values (new.id, v_nombre, v_politica, coalesce(new.created_at, now()));

  return new;
end;
$$;

revoke execute on function public.crear_perfil_de_usuario() from public, anon, authenticated;

create or replace trigger crear_perfil_al_registrarse
  after insert on auth.users
  for each row execute function public.crear_perfil_de_usuario();

-- Perfiles de los usuarios creados antes de este trigger (pruebas de 5A).
-- Los que no tengan nombre o versión de la política en sus metadatos se
-- omiten; verify.sql los lista.
insert into public.perfiles (id, nombre, politica_version, politica_aceptada_en)
select
  u.id,
  btrim(u.raw_user_meta_data ->> 'nombre'),
  btrim(u.raw_user_meta_data ->> 'politica_version'),
  u.created_at
from auth.users u
where char_length(btrim(coalesce(u.raw_user_meta_data ->> 'nombre', ''))) between 1 and 60
  and char_length(btrim(coalesce(u.raw_user_meta_data ->> 'politica_version', ''))) between 1 and 20
on conflict (id) do nothing;

-- Seguridad ------------------------------------------------------------------

alter table public.perfiles enable row level security;

drop policy if exists perfiles_select_propio on public.perfiles;
create policy perfiles_select_propio on public.perfiles
  for select to authenticated
  using ((select auth.uid()) = id);

drop policy if exists perfiles_update_propio on public.perfiles;
create policy perfiles_update_propio on public.perfiles
  for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- Sin insert (lo hace el trigger) ni delete (la cuenta se elimina en 5C).
-- El usuario solo puede cambiar su nombre, no la política que aceptó.
revoke all on table public.perfiles from anon, authenticated;
grant select on table public.perfiles to authenticated;
grant update (nombre) on table public.perfiles to authenticated;

commit;
