-- Paso 2 · ¿Reduce bytes el clustering? Comparación a escala de 90 días.
-- Sobre una sola partición (1,5 MB) no redujo nada. Los bloques de almacenamiento "are adaptively sized based on
-- the size of the table" y "Colocation occurs at the level of the storage blocks, and not at the level of
-- individual rows": si la partición cabe en un bloque, no hay nada que saltarse.
-- https://docs.cloud.google.com/bigquery/docs/clustered-tables (act. 2026-09-03)
-- Las dos consultas leen las MISMAS columnas: BigQuery cobra por columnas leídas.

-- [1] 90 días, sin filtrar por cuenta.
SELECT transaccion_id, cuenta_id, ts_operacion, importe
FROM `sdag-lab-000000.banca.transacciones`
WHERE fecha BETWEEN DATE '2026-06-01' AND DATE '2026-08-29';

-- [2] 90 días, filtrando por la primera columna de clustering.
SELECT transaccion_id, cuenta_id, ts_operacion, importe
FROM `sdag-lab-000000.banca.transacciones`
WHERE fecha BETWEEN DATE '2026-06-01' AND DATE '2026-08-29'
  AND cuenta_id = 'CU0000123';
