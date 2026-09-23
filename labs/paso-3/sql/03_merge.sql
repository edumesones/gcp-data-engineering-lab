-- Paso 3 · El MERGE: la pieza que hace la carga idempotente.
--
-- Relanzarlo con la misma staging no cambia nada: las filas nuevas ya están (no entran por NOT MATCHED) y las
-- correcciones ya tienen ese `updated_at` (la condición del MATCHED pide que el de origen sea MÁS reciente).
--
-- Cuatro decisiones y su porqué:
--
-- 1. **Deduplicación antes del ON.** Si la staging trae dos filas con la misma clave, el MERGE falla:
--    "UPDATE/MERGE must match at most one source row for each target row"
--    https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/dml-syntax (act. 2026-09-03)
--    La tanda trae 5 claves duplicadas a propósito. ROW_NUMBER por `updated_at DESC` deja la más reciente.
--
-- 2. **Filtro de partición en el ON y en el USING.** La poda del destino está documentada:
--    "you can limit which partitions are scanned by including the partitioning column in either a subquery
--     filter, a search_condition filter, or a merge_condition filter"
--    https://docs.cloud.google.com/bigquery/docs/using-dml-with-partitioned-tables (act. 2026-09-03)
--    Importa por dinero: un MERGE que actualiza paga `q' + t'`, donde t' es "The total size of all partitions
--    being updated by the DML statement before any modifications are made" (dml-syntax). Sin filtro, t' es la
--    tabla entera.
--    **Comprobado el 2026-09-12: el filtro en el `ON` SÍ satisface `require_partition_filter`.** Las dos
--    ejecuciones de este MERGE terminaron sin el error de eliminación de particiones.
--    ⚠️ Observado, **no documentado**: ninguna página de Google lo afirma, y la de DML con tablas particionadas
--    no menciona `require_partition_filter`. Si un día falla, el arreglo es repetir el filtro en las cláusulas WHEN.
--
-- 3. **`T.updated_at IS NULL`** en el MATCHED: las filas del paso 2 tienen `updated_at` a NULL, y
--    `S.updated_at > NULL` es NULL, que no entra en el WHEN. Sin esa condición, ninguna corrección se aplicaría.
--
-- 4. **No se toca `importe` ni `cuenta_id` al actualizar.** Una devolución cambia el estado, no reescribe el
--    importe original, y las filas de corrección llegan sin `cuenta_id`. Actualizar solo lo que cambia evita
--    machacar datos buenos con huecos del origen.

MERGE `sdag-lab-000000.banca.transacciones` AS T
USING (
  SELECT * EXCEPT (rn)
  FROM (
    SELECT
      *,
      ROW_NUMBER() OVER (PARTITION BY transaccion_id ORDER BY updated_at DESC) AS rn
    FROM `sdag-lab-000000.banca.stg_transacciones_tanda1`
    WHERE fecha BETWEEN DATE '2026-08-28' AND DATE '2026-09-01'
  )
  WHERE rn = 1
) AS S
ON  T.transaccion_id = S.transaccion_id
AND T.fecha BETWEEN DATE '2026-08-28' AND DATE '2026-09-01'
WHEN MATCHED AND (T.updated_at IS NULL OR S.updated_at > T.updated_at) THEN
  UPDATE SET
    estado     = S.estado,
    updated_at = S.updated_at
WHEN NOT MATCHED THEN
  INSERT (transaccion_id, cuenta_id, fecha, ts_operacion, importe, divisa, tipo, canal, pais_contraparte,
          estado, updated_at)
  VALUES (S.transaccion_id, S.cuenta_id, S.fecha, S.ts_operacion, S.importe, S.divisa, S.tipo, S.canal,
          S.pais_contraparte, S.estado, S.updated_at);
