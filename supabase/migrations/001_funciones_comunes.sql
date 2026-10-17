-- =============================================================================
-- MisLukas · Fase 5B · 001: funciones comunes de los triggers
-- Ejecutar en el SQL Editor. Todo el archivo es una transacción: si algo falla,
-- no queda nada aplicado.
-- =============================================================================

begin;

-- Asigna la hora del servidor a cada fila recibida (docs/06 §6.4.3). El pull
-- de la Fase 5C usa sincronizado_en como cursor; el cliente nunca la envía y,
-- si lo hiciera, este trigger la sobrescribe.
create or replace function public.asignar_sincronizado_en()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.sincronizado_en := now();
  return new;
end;
$$;

-- Mantiene actualizado_en en tablas que no se sincronizan (perfiles).
create or replace function public.asignar_actualizado_en()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.actualizado_en := now();
  return new;
end;
$$;

-- La categoría de un movimiento o presupuesto debe ser predeterminada
-- (usuario_id null) o del mismo usuario. La llave foránea solo comprueba que
-- exista, no de quién es.
create or replace function public.validar_categoria_del_usuario()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.categorias c
    where c.id = new.categoria_id
      and (c.usuario_id is null or c.usuario_id = new.usuario_id)
  ) then
    raise exception 'La categoría no existe o no pertenece al usuario'
      using errcode = '23503';
  end if;
  return new;
end;
$$;

-- Son funciones de trigger: nadie debe llamarlas directamente.
revoke execute on function public.asignar_sincronizado_en() from public, anon, authenticated;
revoke execute on function public.asignar_actualizado_en() from public, anon, authenticated;
revoke execute on function public.validar_categoria_del_usuario() from public, anon, authenticated;

commit;
