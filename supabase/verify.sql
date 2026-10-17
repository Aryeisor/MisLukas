-- =============================================================================
-- MisLukas · Fases 5B y 5C · Verificación del esquema remoto (001 a 009)
--
-- Ejecutar el archivo completo en el SQL Editor (Run). El editor muestra el
-- resultado de la última consulta: una tabla con cada prueba y su resultado.
-- Todo está bien si todas las filas dicen OK.
--
-- Las pruebas con datos crean tres usuarios temporales (A, B y C) y filas de
-- prueba, y al final se revierten: no queda nada guardado. C elimina su
-- cuenta con eliminar_mi_cuenta() (009).
--
-- Las consultas de la PARTE 1 son listados para revisar a mano: selecciona
-- una (desde el comentario hasta el punto y coma) y ejecútala sola.
-- =============================================================================


-- PARTE 1 · Listados ----------------------------------------------------------

-- 1.1 Tablas de public y si tienen RLS activado (todas deben decir true).
select c.relname as tabla, c.relrowsecurity as rls_activado
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind in ('r', 'p')
order by 1;

-- 1.2 Políticas de public y del bucket recibos.
select schemaname as esquema, tablename as tabla, policyname as politica,
       cmd as operacion, roles, qual as using_, with_check
from pg_policies
where schemaname = 'public'
   or (schemaname = 'storage' and policyname like 'recibos_storage_%')
order by 1, 2, 4, 3;

-- 1.3 Permisos de tabla de anon y authenticated en public.
select c.relname as tabla, a.grantee::regrole as rol, a.privilege_type as permiso
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
cross join lateral aclexplode(c.relacl) a
where n.nspname = 'public' and c.relkind = 'r'
  and a.grantee in ('anon'::regrole::oid, 'authenticated'::regrole::oid)
order by 1, 2, 3;

-- 1.4 Permisos por columna (solo perfiles.nombre para authenticated).
select c.relname as tabla, att.attname as columna, a.grantee::regrole as rol,
       a.privilege_type as permiso
from pg_attribute att
join pg_class c on c.oid = att.attrelid
join pg_namespace n on n.oid = c.relnamespace
cross join lateral aclexplode(att.attacl) a
where n.nspname = 'public' and att.attacl is not null
order by 1, 2, 3;

-- 1.5 Usuarios sin perfil (por ejemplo, cuentas de prueba de 5A creadas sin
-- nombre o sin versión de la política). Lo esperado: ninguno.
select u.id, u.created_at
from auth.users u
left join public.perfiles p on p.id = u.id
where p.id is null;


-- PARTE 2 · Pruebas automáticas -------------------------------------------------

create temp table if not exists verificacion_5b (
  n int,
  prueba text,
  resultado text
);

do $verificacion$
declare
  v_a constant uuid := gen_random_uuid();
  v_b constant uuid := gen_random_uuid();
  v_c constant uuid := gen_random_uuid();
  v_sin_politica constant uuid := gen_random_uuid();
  v_mercado constant uuid := '2909b516-0ab3-493e-b8e8-90f8ccf28aed';
  v_ingreso constant uuid := '7d4c2cae-fe7f-4353-80ac-2947009b026d';
  v_mes constant date := date_trunc('month', current_date)::date;
  v_mov_a constant uuid := gen_random_uuid();
  v_cat_a constant uuid := gen_random_uuid();
  v_rec_1 constant uuid := gen_random_uuid();
  v_pre_1 constant uuid := gen_random_uuid();
  v_mov_lww constant uuid := gen_random_uuid();
  v_mov_c constant uuid := gen_random_uuid();
  v_cat_c constant uuid := gen_random_uuid();
  v_claims_a text;
  v_claims_b text;
  v_claims_c_reciente text;
  v_hint text;
  v_pruebas text[] := '{}';
  v_resultados text[] := '{}';
  v_count bigint;
  v_estado text;
  v_ts timestamptz;
  v_uid uuid;
begin
  v_claims_a := json_build_object('sub', v_a, 'role', 'authenticated')::text;
  v_claims_b := json_build_object('sub', v_b, 'role', 'authenticated')::text;
  -- Token emitido justo después de verificar la contraseña (claim amr).
  v_claims_c_reciente := json_build_object(
    'sub', v_c, 'role', 'authenticated',
    'amr', json_build_array(json_build_object(
      'method', 'password', 'timestamp', extract(epoch from now())::bigint))
  )::text;

  -- ---------------------------------------------------------------------------
  -- Estructura (como postgres)
  -- ---------------------------------------------------------------------------

  select count(*) into v_count
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity;
  v_pruebas := array_append(v_pruebas, 'Todas las tablas de public tienen RLS activado');
  v_resultados := array_append(v_resultados, case when v_count = 0 then 'OK'
    else 'FALLO: ' || v_count || ' tabla(s) sin RLS (ver consulta 1.1)' end);

  select count(*) into v_count
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  cross join lateral aclexplode(c.relacl) a
  where n.nspname = 'public' and c.relkind = 'r'
    and (a.grantee = 'anon'::regrole::oid or a.grantee = 0);
  v_pruebas := array_append(v_pruebas, 'anon (y PUBLIC) no tiene permisos en tablas de public');
  v_resultados := array_append(v_resultados, case when v_count = 0 then 'OK'
    else 'FALLO: ' || v_count || ' permiso(s) (ver consulta 1.3)' end);

  select count(*) into v_count
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname in ('categorias', 'movimientos', 'presupuestos', 'recibos')
    and has_table_privilege('authenticated', c.oid, 'SELECT')
    and has_table_privilege('authenticated', c.oid, 'INSERT')
    and has_table_privilege('authenticated', c.oid, 'UPDATE')
    and not has_table_privilege('authenticated', c.oid, 'DELETE')
    and not has_table_privilege('authenticated', c.oid, 'TRUNCATE');
  v_pruebas := array_append(v_pruebas, 'authenticated: SELECT, INSERT y UPDATE (sin DELETE) en las 4 tablas sincronizadas');
  v_resultados := array_append(v_resultados, case when v_count = 4 then 'OK'
    else 'FALLO: solo ' || v_count || ' de 4 tablas (ver consulta 1.3)' end);

  v_pruebas := array_append(v_pruebas, 'authenticated en perfiles: SELECT y UPDATE solo de nombre');
  v_resultados := array_append(v_resultados, case when
        has_table_privilege('authenticated', 'public.perfiles', 'SELECT')
    and not has_table_privilege('authenticated', 'public.perfiles', 'INSERT')
    and not has_table_privilege('authenticated', 'public.perfiles', 'UPDATE')
    and not has_table_privilege('authenticated', 'public.perfiles', 'DELETE')
    and has_column_privilege('authenticated', 'public.perfiles', 'nombre', 'UPDATE')
    and not has_column_privilege('authenticated', 'public.perfiles', 'politica_version', 'UPDATE')
    then 'OK' else 'FALLO (ver consultas 1.3 y 1.4)' end);

  select count(*) into v_count from pg_policies
  where schemaname = 'public' and cmd in ('DELETE', 'ALL');
  v_pruebas := array_append(v_pruebas, 'No hay políticas de DELETE ni FOR ALL en public');
  v_resultados := array_append(v_resultados, case when v_count = 0 then 'OK'
    else 'FALLO: ' || v_count || ' política(s) (ver consulta 1.2)' end);

  select count(*) into v_count from pg_policies where schemaname = 'public';
  v_pruebas := array_append(v_pruebas, 'Políticas en public: 3 por tabla sincronizada + 2 de perfiles = 14');
  v_resultados := array_append(v_resultados, case when v_count = 14 then 'OK'
    else 'FALLO: hay ' || v_count || ' (ver consulta 1.2)' end);

  select count(*) into v_count from pg_policies
  where schemaname = 'storage' and tablename = 'objects'
    and policyname like 'recibos_storage_%'
    and cmd in ('SELECT', 'INSERT', 'UPDATE', 'DELETE');
  v_pruebas := array_append(v_pruebas, 'Storage: políticas SELECT, INSERT, UPDATE y DELETE del bucket recibos (009)');
  v_resultados := array_append(v_resultados, case when v_count = 4 then 'OK'
    else 'FALLO: hay ' || v_count || ' de 4' end);

  select count(*) into v_count
  from pg_policies d
  join pg_policies s on s.schemaname = d.schemaname and s.tablename = d.tablename
  where d.schemaname = 'storage' and d.tablename = 'objects'
    and d.policyname = 'recibos_storage_delete_propios' and d.cmd = 'DELETE'
    and 'authenticated' = any(d.roles)
    and s.policyname = 'recibos_storage_select_propios'
    and d.qual = s.qual;
  v_pruebas := array_append(v_pruebas, 'Storage: el delete exige la carpeta propia, igual que el select');
  v_resultados := array_append(v_resultados, case when v_count = 1 then 'OK' else 'FALLO' end);

  select count(*) into v_count from storage.buckets
  where id = 'recibos' and not public and file_size_limit = 5242880
    and allowed_mime_types @> array['image/jpeg', 'image/png']
    and array_length(allowed_mime_types, 1) = 2;
  v_pruebas := array_append(v_pruebas, 'Bucket recibos privado, 5 MB, solo JPEG y PNG');
  v_resultados := array_append(v_resultados, case when v_count = 1 then 'OK' else 'FALLO' end);

  select count(*) into v_count
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in ('asignar_sincronizado_en', 'asignar_actualizado_en',
                      'validar_categoria_del_usuario', 'crear_perfil_de_usuario',
                      'conservar_ultima_escritura', 'eliminar_mi_cuenta')
    and 'search_path=""' = any(p.proconfig)
    and p.prosecdef = (p.proname in ('crear_perfil_de_usuario', 'eliminar_mi_cuenta'));
  v_pruebas := array_append(v_pruebas, 'Funciones con search_path vacío; solo crear_perfil_de_usuario y eliminar_mi_cuenta son SECURITY DEFINER');
  v_resultados := array_append(v_resultados, case when v_count = 6 then 'OK'
    else 'FALLO: ' || v_count || ' de 6 correctas' end);

  v_pruebas := array_append(v_pruebas, 'eliminar_mi_cuenta: solo authenticated puede ejecutarla');
  v_resultados := array_append(v_resultados, case when
        has_function_privilege('authenticated', 'public.eliminar_mi_cuenta()', 'EXECUTE')
    and not has_function_privilege('anon', 'public.eliminar_mi_cuenta()', 'EXECUTE')
    and not exists (
      select 1 from pg_proc p cross join lateral aclexplode(p.proacl) a
      where p.oid = 'public.eliminar_mi_cuenta()'::regprocedure and a.grantee = 0)
    then 'OK' else 'FALLO' end);

  select count(*) into v_count
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and not t.tgisinternal
    and t.tgfoid = 'public.conservar_ultima_escritura()'::regprocedure
    and c.relname in ('categorias', 'movimientos', 'presupuestos', 'recibos');
  v_pruebas := array_append(v_pruebas, 'Última escritura gana: trigger en las 4 tablas sincronizadas (009)');
  v_resultados := array_append(v_resultados, case when v_count = 4 then 'OK'
    else 'FALLO: está en ' || v_count || ' de 4' end);

  select count(*) into v_count from public.categorias
  where usuario_id is null and eliminado_en is null;
  v_pruebas := array_append(v_pruebas, 'Existen las 7 categorías predeterminadas');
  v_resultados := array_append(v_resultados, case when v_count = 7 then 'OK'
    else 'FALLO: hay ' || v_count end);

  v_pruebas := array_append(v_pruebas, 'Recibos: índice único parcial por (usuario_id, movimiento_id) (migración 008)');
  v_resultados := array_append(v_resultados, case
    when exists (select 1 from pg_indexes
                 where schemaname = 'public' and indexname = 'recibos_movimiento_activo_key')
      then 'FALLO: sigue el índice anterior solo por movimiento_id (ejecuta 008)'
    when exists (select 1 from pg_indexes
                 where schemaname = 'public' and tablename = 'recibos'
                   and indexname = 'recibos_usuario_movimiento_activo_key'
                   and indexdef like '%UNIQUE%(usuario_id, movimiento_id)%WHERE (eliminado_en IS NULL)%')
      then 'OK'
    else 'FALLO: falta recibos_usuario_movimiento_activo_key' end);

  -- ---------------------------------------------------------------------------
  -- Pruebas con datos. Todo este bloque se revierte al final.
  -- ---------------------------------------------------------------------------
  begin
    insert into auth.users (instance_id, id, aud, role, email,
                            raw_user_meta_data, raw_app_meta_data, created_at, updated_at)
    values
      ('00000000-0000-0000-0000-000000000000', v_a, 'authenticated', 'authenticated',
       'verificacion-a-' || v_a || '@mislukas.invalid',
       '{"nombre": "Usuario A", "politica_version": "1"}', '{}', now(), now()),
      ('00000000-0000-0000-0000-000000000000', v_b, 'authenticated', 'authenticated',
       'verificacion-b-' || v_b || '@mislukas.invalid',
       '{"nombre": "Usuario B", "politica_version": "1"}', '{}', now(), now()),
      ('00000000-0000-0000-0000-000000000000', v_c, 'authenticated', 'authenticated',
       'verificacion-d-' || v_c || '@mislukas.invalid',
       '{"nombre": "Usuario C", "politica_version": "1"}', '{}', now(), now());

    begin
      insert into auth.users (instance_id, id, aud, role, email,
                              raw_user_meta_data, raw_app_meta_data, created_at, updated_at)
      values ('00000000-0000-0000-0000-000000000000', v_sin_politica, 'authenticated',
              'authenticated', 'verificacion-c-' || v_sin_politica || '@mislukas.invalid',
              '{"nombre": "Sin política"}', '{}', now(), now());
      v_estado := 'FALLO: se permitió';
    exception when others then
      v_estado := case when sqlstate = '23514' then 'OK' else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'Registro sin versión de la política: rechazado');
    v_resultados := array_append(v_resultados, v_estado);

    -- =========================== Como usuario A ============================
    perform set_config('request.jwt.claims', v_claims_a, true);
    set local role authenticated;

    select count(*) into v_count from public.perfiles
    where id = v_a and nombre = 'Usuario A' and politica_version = '1';
    v_pruebas := array_append(v_pruebas, 'A: el trigger creó su perfil con nombre y política');
    v_resultados := array_append(v_resultados, case when v_count = 1 then 'OK' else 'FALLO' end);

    select count(*) into v_count from public.categorias where usuario_id is null;
    v_pruebas := array_append(v_pruebas, 'A: ve las 7 categorías predeterminadas');
    v_resultados := array_append(v_resultados, case when v_count = 7 then 'OK' else 'FALLO: ve ' || v_count end);

    begin
      insert into public.movimientos (id, categoria_id, tipo, monto, fecha, descripcion,
                                      origen, creado_en, actualizado_en, sincronizado_en)
      values (v_mov_a, v_mercado, 'gasto', 87400, current_date, 'Prueba A', 'foto',
              now(), now(), '2000-01-01T00:00:00Z');
      select usuario_id, sincronizado_en into v_uid, v_ts
      from public.movimientos where id = v_mov_a;
      v_estado := case
        when v_uid is distinct from v_a then 'FALLO: usuario_id no es auth.uid()'
        when v_ts < '2001-01-01'::timestamptz then 'FALLO: sincronizado_en vino del cliente'
        else 'OK' end;
    exception when others then
      v_estado := 'FALLO: ' || sqlstate || ' ' || sqlerrm;
    end;
    v_pruebas := array_append(v_pruebas, 'A: registra un gasto; usuario_id y sincronizado_en los pone el servidor');
    v_resultados := array_append(v_resultados, v_estado);

    begin
      insert into public.movimientos (id, categoria_id, tipo, monto, fecha, descripcion,
                                      origen, creado_en, actualizado_en)
      values (gen_random_uuid(), v_ingreso, 'ingreso', 3500000, current_date, 'Salario',
              'manual', now(), now());
      v_estado := 'OK';
    exception when others then
      v_estado := 'FALLO: ' || sqlstate || ' ' || sqlerrm;
    end;
    v_pruebas := array_append(v_pruebas, 'A: registra un ingreso (categoría Ingreso)');
    v_resultados := array_append(v_resultados, v_estado);

    begin
      insert into public.movimientos (id, categoria_id, tipo, monto, fecha, descripcion,
                                      origen, creado_en, actualizado_en)
      values (gen_random_uuid(), v_mercado, 'gasto', 0, current_date, 'x', 'manual', now(), now());
      v_estado := 'FALLO: se permitió';
    exception when others then
      v_estado := case when sqlstate = '23514' then 'OK' else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'A: monto 0 rechazado (CHECK)');
    v_resultados := array_append(v_resultados, v_estado);

    begin
      insert into public.movimientos (id, categoria_id, tipo, monto, fecha, descripcion,
                                      origen, creado_en, actualizado_en)
      values (gen_random_uuid(), v_mercado, 'saldo_inicial', 1000, current_date, 'x', 'manual', now(), now());
      v_estado := 'FALLO: se permitió';
    exception when others then
      v_estado := case when sqlstate = '23514' then 'OK' else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'A: tipo desconocido rechazado (CHECK)');
    v_resultados := array_append(v_resultados, v_estado);

    begin
      update public.movimientos set usuario_id = v_b where id = v_mov_a;
      v_estado := 'FALLO: se permitió';
    exception when others then
      v_estado := case when sqlstate = '42501' then 'OK' else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'A: no puede pasar su movimiento a nombre de B');
    v_resultados := array_append(v_resultados, v_estado);

    begin
      insert into public.categorias (id, nombre, tipo, creado_en, actualizado_en)
      values (v_cat_a, 'Mascotas', 'gasto', now(), now());
      v_estado := 'OK';
    exception when others then
      v_estado := 'FALLO: ' || sqlstate || ' ' || sqlerrm;
    end;
    v_pruebas := array_append(v_pruebas, 'A: crea una categoría personalizada');
    v_resultados := array_append(v_resultados, v_estado);

    update public.categorias set nombre = 'Cambiada' where id = v_mercado;
    get diagnostics v_count = row_count;
    v_pruebas := array_append(v_pruebas, 'A: no puede modificar una categoría predeterminada');
    v_resultados := array_append(v_resultados, case when v_count = 0 then 'OK' else 'FALLO: la modificó' end);

    begin
      insert into public.categorias (id, usuario_id, nombre, tipo, creado_en, actualizado_en)
      values (gen_random_uuid(), null, 'Falsa predeterminada', 'gasto', now(), now());
      v_estado := 'FALLO: se permitió';
    exception when others then
      v_estado := case when sqlstate = '42501' then 'OK' else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'A: no puede crear categorías predeterminadas (usuario_id null)');
    v_resultados := array_append(v_resultados, v_estado);

    -- Borrado lógico y unicidad de presupuestos
    begin
      insert into public.presupuestos (id, categoria_id, mes, monto_limite, creado_en, actualizado_en)
      values (v_pre_1, v_mercado, v_mes, 800000, now(), now());
      v_estado := 'OK';
    exception when others then
      v_estado := 'FALLO: ' || sqlstate || ' ' || sqlerrm;
    end;
    v_pruebas := array_append(v_pruebas, 'A: crea un presupuesto de Mercado para este mes');
    v_resultados := array_append(v_resultados, v_estado);

    begin
      insert into public.presupuestos (id, categoria_id, mes, monto_limite, creado_en, actualizado_en)
      values (gen_random_uuid(), v_mercado, v_mes, 900000, now(), now());
      v_estado := 'FALLO: se permitió';
    exception when others then
      v_estado := case when sqlstate = '23505' then 'OK' else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'A: un segundo presupuesto activo igual se rechaza');
    v_resultados := array_append(v_resultados, v_estado);

    begin
      update public.presupuestos set eliminado_en = now(), actualizado_en = now() where id = v_pre_1;
      insert into public.presupuestos (id, categoria_id, mes, monto_limite, creado_en, actualizado_en)
      values (gen_random_uuid(), v_mercado, v_mes, 900000, now(), now());
      v_estado := 'OK';
    exception when others then
      v_estado := 'FALLO: ' || sqlstate || ' ' || sqlerrm;
    end;
    v_pruebas := array_append(v_pruebas, 'A: crear, eliminar (lógico) y volver a crear el mismo presupuesto funciona');
    v_resultados := array_append(v_resultados, v_estado);

    -- Borrado lógico y unicidad de recibos
    begin
      insert into public.recibos (id, movimiento_id, ruta_storage, total_detectado,
                                  comercio_detectado, creado_en, actualizado_en)
      values (v_rec_1, v_mov_a, v_a || '/' || v_rec_1 || '.jpg', 87400, 'Éxito', now(), now());
      v_estado := 'OK';
    exception when others then
      v_estado := 'FALLO: ' || sqlstate || ' ' || sqlerrm;
    end;
    v_pruebas := array_append(v_pruebas, 'A: guarda el recibo de su movimiento');
    v_resultados := array_append(v_resultados, v_estado);

    begin
      insert into public.recibos (id, movimiento_id, creado_en, actualizado_en)
      values (gen_random_uuid(), v_mov_a, now(), now());
      v_estado := 'FALLO: se permitió';
    exception when others then
      v_estado := case when sqlstate = '23505' then 'OK' else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'A: un segundo recibo activo del mismo movimiento se rechaza');
    v_resultados := array_append(v_resultados, v_estado);

    begin
      update public.recibos set eliminado_en = now(), actualizado_en = now() where id = v_rec_1;
      insert into public.recibos (id, movimiento_id, creado_en, actualizado_en)
      values (gen_random_uuid(), v_mov_a, now(), now());
      v_estado := 'OK';
    exception when others then
      v_estado := 'FALLO: ' || sqlstate || ' ' || sqlerrm;
    end;
    v_pruebas := array_append(v_pruebas, 'A: tras eliminar (lógico) el recibo, puede crear otro');
    v_resultados := array_append(v_resultados, v_estado);

    begin
      insert into public.recibos (id, movimiento_id, ruta_storage, creado_en, actualizado_en)
      values (gen_random_uuid(), v_mov_a, v_b || '/ajeno.jpg', now(), now());
      v_estado := 'FALLO: se permitió';
    exception when others then
      v_estado := case when sqlstate = '23514' then 'OK' else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'A: ruta_storage fuera de su carpeta rechazada');
    v_resultados := array_append(v_resultados, v_estado);

    -- Última escritura gana y la eliminación prevalece (009)
    insert into public.movimientos (id, categoria_id, tipo, monto, fecha, descripcion,
                                    origen, creado_en, actualizado_en)
    values (v_mov_lww, v_mercado, 'gasto', 1000, current_date, 'LWW', 'manual',
            '2026-09-22T10:00:00Z', '2026-09-22T10:00:00Z');

    update public.movimientos set monto = 2000, actualizado_en = '2026-09-22T09:00:00Z'
    where id = v_mov_lww;
    select monto into v_count from public.movimientos where id = v_mov_lww;
    v_pruebas := array_append(v_pruebas, 'LWW: una edición más vieja no reemplaza la guardada');
    v_resultados := array_append(v_resultados, case when v_count = 1000 then 'OK'
      else 'FALLO: quedó ' || v_count end);

    -- Como el upsert de PostgREST.
    insert into public.movimientos (id, categoria_id, tipo, monto, fecha, descripcion,
                                    origen, creado_en, actualizado_en)
    values (v_mov_lww, v_mercado, 'gasto', 2500, current_date, 'LWW', 'manual',
            '2026-09-22T10:00:00Z', '2026-09-22T09:30:00Z')
    on conflict (id) do update
      set monto = excluded.monto, actualizado_en = excluded.actualizado_en;
    select monto into v_count from public.movimientos where id = v_mov_lww;
    v_pruebas := array_append(v_pruebas, 'LWW: un upsert con una versión más vieja no la reemplaza');
    v_resultados := array_append(v_resultados, case when v_count = 1000 then 'OK'
      else 'FALLO: quedó ' || v_count end);

    update public.movimientos set monto = 3000, actualizado_en = '2026-09-22T11:00:00Z'
    where id = v_mov_lww;
    select monto into v_count from public.movimientos where id = v_mov_lww;
    v_pruebas := array_append(v_pruebas, 'LWW: una edición más nueva sí la reemplaza');
    v_resultados := array_append(v_resultados, case when v_count = 3000 then 'OK'
      else 'FALLO: quedó ' || v_count end);

    update public.movimientos
    set eliminado_en = '2026-09-22T08:00:00Z', actualizado_en = '2026-09-22T08:00:00Z'
    where id = v_mov_lww;
    select count(*) into v_count from public.movimientos
    where id = v_mov_lww and eliminado_en is not null;
    v_pruebas := array_append(v_pruebas, 'LWW: una eliminación se aplica aunque sea más vieja');
    v_resultados := array_append(v_resultados, case when v_count = 1 then 'OK' else 'FALLO' end);

    update public.movimientos
    set eliminado_en = null, monto = 4000, actualizado_en = '2026-09-22T12:00:00Z'
    where id = v_mov_lww;
    select count(*) into v_count from public.movimientos
    where id = v_mov_lww and eliminado_en is not null and monto = 3000;
    v_pruebas := array_append(v_pruebas, 'LWW: un registro eliminado no revive ni cambia');
    v_resultados := array_append(v_resultados, case when v_count = 1 then 'OK' else 'FALLO' end);

    -- Perfil
    begin
      update public.perfiles set politica_version = '0' where id = v_a;
      v_estado := 'FALLO: se permitió';
    exception when others then
      v_estado := case when sqlstate = '42501' then 'OK' else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'A: no puede cambiar la versión de la política aceptada');
    v_resultados := array_append(v_resultados, v_estado);

    update public.perfiles set nombre = 'Usuario A editado' where id = v_a;
    get diagnostics v_count = row_count;
    v_pruebas := array_append(v_pruebas, 'A: puede cambiar su nombre');
    v_resultados := array_append(v_resultados, case when v_count = 1 then 'OK' else 'FALLO' end);

    -- Storage: inserta directamente en storage.objects, como lo hace la API
    -- de Storage con el token del usuario.
    begin
      insert into storage.objects (bucket_id, name)
      values ('recibos', v_a || '/' || v_rec_1 || '.jpg');
      v_estado := 'OK';
    exception when others then
      v_estado := 'FALLO: ' || sqlstate || ' ' || sqlerrm;
    end;
    v_pruebas := array_append(v_pruebas, 'Storage: A sube un archivo a su carpeta');
    v_resultados := array_append(v_resultados, v_estado);

    begin
      insert into storage.objects (bucket_id, name)
      values ('recibos', v_a || '/sub/carpeta.jpg');
      v_estado := 'FALLO: se permitió';
    exception when others then
      v_estado := case when sqlstate = '42501' then 'OK' else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'Storage: A no puede crear subcarpetas');
    v_resultados := array_append(v_resultados, v_estado);

    -- =========================== Como usuario B ============================
    perform set_config('request.jwt.claims', v_claims_b, true);
    set local role authenticated;

    select (select count(*) from public.movimientos)
         + (select count(*) from public.presupuestos)
         + (select count(*) from public.recibos)
      into v_count;
    v_pruebas := array_append(v_pruebas, 'B: no ve movimientos, presupuestos ni recibos de A');
    v_resultados := array_append(v_resultados, case when v_count = 0 then 'OK' else 'FALLO: ve ' || v_count || ' fila(s)' end);

    select count(*) into v_count from public.perfiles;
    v_pruebas := array_append(v_pruebas, 'B: solo ve su propio perfil');
    v_resultados := array_append(v_resultados, case when v_count = 1 then 'OK' else 'FALLO: ve ' || v_count end);

    select count(*) into v_count from public.categorias where id = v_cat_a;
    v_pruebas := array_append(v_pruebas, 'B: no ve la categoría personalizada de A');
    v_resultados := array_append(v_resultados, case when v_count = 0 then 'OK' else 'FALLO' end);

    update public.movimientos set monto = 1 where id = v_mov_a;
    get diagnostics v_count = row_count;
    v_pruebas := array_append(v_pruebas, 'B: no puede modificar el movimiento de A');
    v_resultados := array_append(v_resultados, case when v_count = 0 then 'OK' else 'FALLO: lo modificó' end);

    update public.presupuestos set monto_limite = 1 where usuario_id = v_a;
    get diagnostics v_count = row_count;
    v_pruebas := array_append(v_pruebas, 'B: no puede modificar los presupuestos de A');
    v_resultados := array_append(v_resultados, case when v_count = 0 then 'OK' else 'FALLO: los modificó' end);

    update public.perfiles set nombre = 'Cambiado por B' where id = v_a;
    get diagnostics v_count = row_count;
    v_pruebas := array_append(v_pruebas, 'B: no puede modificar el perfil de A');
    v_resultados := array_append(v_resultados, case when v_count = 0 then 'OK' else 'FALLO: lo modificó' end);

    begin
      insert into public.movimientos (id, usuario_id, categoria_id, tipo, monto, fecha,
                                      descripcion, origen, creado_en, actualizado_en)
      values (gen_random_uuid(), v_a, v_mercado, 'gasto', 1000, current_date, 'x', 'manual', now(), now());
      v_estado := 'FALLO: se permitió';
    exception when others then
      v_estado := case when sqlstate = '42501' then 'OK' else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'B: no puede insertar un movimiento a nombre de A');
    v_resultados := array_append(v_resultados, v_estado);

    begin
      insert into public.movimientos (id, categoria_id, tipo, monto, fecha, descripcion,
                                      origen, creado_en, actualizado_en)
      values (gen_random_uuid(), v_cat_a, 'gasto', 1000, current_date, 'x', 'manual', now(), now());
      v_estado := 'FALLO: se permitió';
    exception when others then
      v_estado := case when sqlstate = '23503' then 'OK' else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'B: no puede usar la categoría personalizada de A');
    v_resultados := array_append(v_resultados, v_estado);

    begin
      insert into public.recibos (id, movimiento_id, creado_en, actualizado_en)
      values (gen_random_uuid(), v_mov_a, now(), now());
      v_estado := 'FALLO: se permitió';
    exception when others then
      v_estado := case when sqlstate = '23503' then 'OK' else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'B: no puede asociar un recibo al movimiento de A');
    v_resultados := array_append(v_resultados, v_estado);

    begin
      delete from public.movimientos where id = v_mov_a;
      v_estado := 'FALLO: se permitió';
    exception when others then
      v_estado := case when sqlstate = '42501' then 'OK' else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'Nadie puede borrar físicamente (sin permiso DELETE)');
    v_resultados := array_append(v_resultados, v_estado);

    select count(*) into v_count from storage.objects where bucket_id = 'recibos';
    v_pruebas := array_append(v_pruebas, 'Storage: B no ve los archivos de A');
    v_resultados := array_append(v_resultados, case when v_count = 0 then 'OK' else 'FALLO: ve ' || v_count end);

    begin
      insert into storage.objects (bucket_id, name)
      values ('recibos', v_a || '/intruso.jpg');
      v_estado := 'FALLO: se permitió';
    exception when others then
      v_estado := case when sqlstate = '42501' then 'OK' else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'Storage: B no puede subir a la carpeta de A');
    v_resultados := array_append(v_resultados, v_estado);

    update storage.objects set metadata = '{}' where bucket_id = 'recibos';
    get diagnostics v_count = row_count;
    v_pruebas := array_append(v_pruebas, 'Storage: B no puede modificar los archivos de A');
    v_resultados := array_append(v_resultados, case when v_count = 0 then 'OK' else 'FALLO' end);

    begin
      delete from storage.objects where bucket_id = 'recibos';
      get diagnostics v_count = row_count;
      v_estado := case when v_count = 0 then 'OK' else 'FALLO: borró ' || v_count end;
    exception when others then
      -- Storage puede impedir todo borrado directo con SQL: tampoco borra nada.
      v_estado := 'OK';
    end;
    v_pruebas := array_append(v_pruebas, 'Storage: B no puede borrar los archivos de A');
    v_resultados := array_append(v_resultados, v_estado);

    -- ======================== Eliminar la cuenta (009) ======================
    -- A sin verificar la contraseña (token sin amr).
    perform set_config('request.jwt.claims', v_claims_a, true);
    set local role authenticated;
    begin
      perform public.eliminar_mi_cuenta();
      v_estado := 'FALLO: se permitió';
    exception when others then
      get stacked diagnostics v_hint = pg_exception_hint;
      v_estado := case when sqlstate = 'P0001' and v_hint = 'reautenticacion' then 'OK'
        else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'Eliminar la cuenta sin verificar la contraseña: rechazado');
    v_resultados := array_append(v_resultados, v_estado);

    -- A con la contraseña verificada hace 10 minutos.
    perform set_config('request.jwt.claims', json_build_object(
      'sub', v_a, 'role', 'authenticated',
      'amr', json_build_array(json_build_object(
        'method', 'password', 'timestamp', extract(epoch from now())::bigint - 600))
    )::text, true);
    begin
      perform public.eliminar_mi_cuenta();
      v_estado := 'FALLO: se permitió';
    exception when others then
      get stacked diagnostics v_hint = pg_exception_hint;
      v_estado := case when sqlstate = 'P0001' and v_hint = 'reautenticacion' then 'OK'
        else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'Eliminar la cuenta con la contraseña verificada hace 10 min: rechazado');
    v_resultados := array_append(v_resultados, v_estado);

    -- A con la contraseña recién verificada, pero con un archivo en Storage.
    perform set_config('request.jwt.claims', json_build_object(
      'sub', v_a, 'role', 'authenticated',
      'amr', json_build_array(json_build_object(
        'method', 'password', 'timestamp', extract(epoch from now())::bigint))
    )::text, true);
    begin
      perform public.eliminar_mi_cuenta();
      v_estado := 'FALLO: se permitió con archivos en Storage';
    exception when others then
      get stacked diagnostics v_hint = pg_exception_hint;
      v_estado := case when sqlstate = 'P0001' and v_hint = 'archivos_pendientes' then 'OK'
        else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'Eliminar la cuenta con archivos en Storage: rechazado');
    v_resultados := array_append(v_resultados, v_estado);

    -- C crea datos y elimina su cuenta con la contraseña recién verificada.
    perform set_config('request.jwt.claims', v_claims_c_reciente, true);
    set local role authenticated;
    begin
      insert into public.categorias (id, nombre, tipo, creado_en, actualizado_en)
      values (v_cat_c, 'Mascotas C', 'gasto', now(), now());
      insert into public.movimientos (id, categoria_id, tipo, monto, fecha, descripcion,
                                      origen, creado_en, actualizado_en)
      values (v_mov_c, v_cat_c, 'gasto', 5000, current_date, 'Prueba C', 'foto', now(), now());
      insert into public.recibos (id, movimiento_id, total_detectado, creado_en, actualizado_en)
      values (gen_random_uuid(), v_mov_c, 5000, now(), now());
      insert into public.presupuestos (id, categoria_id, mes, monto_limite, creado_en, actualizado_en)
      values (gen_random_uuid(), v_mercado, v_mes, 100000, now(), now());
      perform public.eliminar_mi_cuenta();
      v_estado := 'OK';
    exception when others then
      v_estado := 'FALLO: ' || sqlstate || ' ' || sqlerrm;
    end;
    v_pruebas := array_append(v_pruebas, 'C elimina su cuenta con la contraseña recién verificada');
    v_resultados := array_append(v_resultados, v_estado);

    reset role;
    perform set_config('request.jwt.claims', '', true);

    select (select count(*) from auth.users where id = v_c)
         + (select count(*) from public.perfiles where id = v_c)
         + (select count(*) from public.categorias where usuario_id = v_c)
         + (select count(*) from public.movimientos where usuario_id = v_c)
         + (select count(*) from public.presupuestos where usuario_id = v_c)
         + (select count(*) from public.recibos where usuario_id = v_c)
      into v_count;
    v_pruebas := array_append(v_pruebas, 'Después de eliminar la cuenta de C no queda nada suyo');
    v_resultados := array_append(v_resultados, case when v_count = 0 then 'OK'
      else 'FALLO: quedan ' || v_count || ' fila(s)' end);

    select count(*) into v_count from auth.users where id in (v_a, v_b);
    v_pruebas := array_append(v_pruebas, 'Eliminar la cuenta de C no toca a A ni a B');
    v_resultados := array_append(v_resultados, case
      when v_count = 2 and exists (select 1 from public.movimientos where usuario_id = v_a)
        then 'OK' else 'FALLO' end);

    -- ============================ Como anon ================================
    perform set_config('request.jwt.claims', '{"role": "anon"}', true);
    set local role anon;

    begin
      select count(*) into v_count from public.categorias;
      v_estado := 'FALLO: pudo leer';
    exception when others then
      v_estado := case when sqlstate = '42501' then 'OK' else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'anon: no puede leer categorías');
    v_resultados := array_append(v_resultados, v_estado);

    begin
      select count(*) into v_count from public.movimientos;
      v_estado := 'FALLO: pudo leer';
    exception when others then
      v_estado := case when sqlstate = '42501' then 'OK' else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'anon: no puede leer movimientos');
    v_resultados := array_append(v_resultados, v_estado);

    begin
      select count(*) into v_count from public.perfiles;
      v_estado := 'FALLO: pudo leer';
    exception when others then
      v_estado := case when sqlstate = '42501' then 'OK' else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'anon: no puede leer perfiles');
    v_resultados := array_append(v_resultados, v_estado);

    begin
      perform public.eliminar_mi_cuenta();
      v_estado := 'FALLO: pudo ejecutarla';
    exception when others then
      v_estado := case when sqlstate = '42501' then 'OK' else 'FALLO: ' || sqlstate || ' ' || sqlerrm end;
    end;
    v_pruebas := array_append(v_pruebas, 'anon: no puede ejecutar eliminar_mi_cuenta');
    v_resultados := array_append(v_resultados, v_estado);

    -- Revierte todo lo hecho en este bloque (usuarios, filas y archivos).
    raise exception using errcode = 'ML001', message = 'Revertir los datos de prueba';
  exception when sqlstate 'ML001' then
    null;
  end;

  reset role;
  perform set_config('request.jwt.claims', '', true);

  -- La tabla temporal puede venir de una ejecución anterior en la misma sesión.
  delete from verificacion_5b;
  insert into verificacion_5b (n, prueba, resultado)
  select t.n, t.prueba, t.resultado
  from unnest(v_pruebas, v_resultados) with ordinality as t(prueba, resultado, n);
end;
$verificacion$;

select n as "#", prueba, resultado
from verificacion_5b
order by n;
