-- =============================================================================
-- MisLukas · Fase 5B · 007: bucket privado de recibos
-- Ruta de cada archivo: {usuario_id}/{id_del_recibo}.jpg (docs/08 §8.5.5).
-- Sin acceso público: la app mostrará las imágenes con URLs firmadas.
-- =============================================================================

begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('recibos', 'recibos', false, 5242880, array['image/jpeg', 'image/png'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Cada usuario solo lee, sube y reemplaza archivos de su propia carpeta, sin
-- subcarpetas. Sin política de delete: el borrado de archivos llega en 5C.

drop policy if exists recibos_storage_select_propios on storage.objects;
create policy recibos_storage_select_propios on storage.objects
  for select to authenticated
  using (
    bucket_id = 'recibos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and array_length(storage.foldername(name), 1) = 1
  );

drop policy if exists recibos_storage_insert_propios on storage.objects;
create policy recibos_storage_insert_propios on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'recibos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and array_length(storage.foldername(name), 1) = 1
  );

drop policy if exists recibos_storage_update_propios on storage.objects;
create policy recibos_storage_update_propios on storage.objects
  for update to authenticated
  using (
    bucket_id = 'recibos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and array_length(storage.foldername(name), 1) = 1
  )
  with check (
    bucket_id = 'recibos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and array_length(storage.foldername(name), 1) = 1
  );

commit;
