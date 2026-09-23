-- Paso 4 · La comparación que es el criterio: ¿un backfill de tres días deja lo mismo que tres ejecuciones diarias?
--
-- Dos comprobaciones independientes, para no depender de una sola:
--   [1] Resumen por tabla: filas, ids únicos y huella de contenido. La huella es
--       BIT_XOR(FARM_FINGERPRINT(TO_JSON_STRING(t))): cambia si cambia cualquier fila y no depende del orden.
--   [2] Diferencia fila a fila en los dos sentidos con EXCEPT DISTINCT. Si el backfill y las diarias son
--       idénticos, las dos cuentas dan 0. No depende de que el hash no colisione.
--   [3] Filas por día, para contrastarlas con labs/paso-4/data/manifiesto_incremental.json.
--
-- Las dos tablas exigen filtro de partición: todas las lecturas van acotadas a los tres días.

-- [1] RESUMEN POR TABLA
SELECT 'p4_diario' AS tabla,
       COUNT(*) AS filas,
       COUNT(DISTINCT transaccion_id) AS ids_unicos,
       BIT_XOR(FARM_FINGERPRINT(TO_JSON_STRING(t))) AS huella
FROM `sdag-lab-000000.banca.p4_diario` t
WHERE fecha BETWEEN DATE '2026-09-02' AND DATE '2026-09-04'
UNION ALL
SELECT 'p4_backfill',
       COUNT(*),
       COUNT(DISTINCT transaccion_id),
       BIT_XOR(FARM_FINGERPRINT(TO_JSON_STRING(t)))
FROM `sdag-lab-000000.banca.p4_backfill` t
WHERE fecha BETWEEN DATE '2026-09-02' AND DATE '2026-09-04';

-- [2] DIFERENCIA FILA A FILA EN LOS DOS SENTIDOS
SELECT
  (SELECT COUNT(*) FROM (
     SELECT * FROM `sdag-lab-000000.banca.p4_diario`
     WHERE fecha BETWEEN DATE '2026-09-02' AND DATE '2026-09-04'
     EXCEPT DISTINCT
     SELECT * FROM `sdag-lab-000000.banca.p4_backfill`
     WHERE fecha BETWEEN DATE '2026-09-02' AND DATE '2026-09-04'
  )) AS filas_solo_en_diario,
  (SELECT COUNT(*) FROM (
     SELECT * FROM `sdag-lab-000000.banca.p4_backfill`
     WHERE fecha BETWEEN DATE '2026-09-02' AND DATE '2026-09-04'
     EXCEPT DISTINCT
     SELECT * FROM `sdag-lab-000000.banca.p4_diario`
     WHERE fecha BETWEEN DATE '2026-09-02' AND DATE '2026-09-04'
  )) AS filas_solo_en_backfill;

-- [3] FILAS POR DÍA EN CADA TABLA
SELECT fecha,
       COUNTIF(origen = 'p4_diario') AS filas_diario,
       COUNTIF(origen = 'p4_backfill') AS filas_backfill
FROM (
  SELECT fecha, 'p4_diario' AS origen FROM `sdag-lab-000000.banca.p4_diario`
  WHERE fecha BETWEEN DATE '2026-09-02' AND DATE '2026-09-04'
  UNION ALL
  SELECT fecha, 'p4_backfill' FROM `sdag-lab-000000.banca.p4_backfill`
  WHERE fecha BETWEEN DATE '2026-09-02' AND DATE '2026-09-04'
)
GROUP BY fecha
ORDER BY fecha;
