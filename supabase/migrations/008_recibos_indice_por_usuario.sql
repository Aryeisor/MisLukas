-- =============================================================================
-- MisLukas · Fase 5B · 008: unicidad de recibos por usuario
--
-- El índice único parcial de 005 era solo sobre movimiento_id. Un usuario que
-- intentaba asociar un recibo al movimiento de otro recibía 23505 (clave
-- duplicada) en lugar de 23503 (llave foránea): la unicidad se evalúa al
-- insertar la fila, antes que la llave foránea, y el código de error le
-- revelaba que ese movimiento existe y tiene un recibo activo.
--
-- Con usuario_id en el índice, la fila de otro usuario nunca choca con la del
-- dueño y el rechazo lo da la llave foránea compuesta. Para el dueño la regla
-- no cambia: un recibo activo por movimiento.
--
-- Repetible: se puede ejecutar después de la 005 nueva o de la anterior.
-- =============================================================================

begin;

drop index if exists public.recibos_movimiento_activo_key;

create unique index if not exists recibos_usuario_movimiento_activo_key
  on public.recibos (usuario_id, movimiento_id)
  where eliminado_en is null;

commit;
