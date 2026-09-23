-- Paso 2 · Consultas que demuestran (y rompen) la poda por partición.
-- Se ejecutan con la cuenta de servicio impersonada. Cada una se lanza con un job id propio para poder leer
-- después `statistics.query.totalPartitionsProcessed` y `totalBytesProcessed` con `bq show -j`.
--
-- Se compara `totalBytesProcessed`, NO `totalBytesBilled`: hay un mínimo de 10 MB facturados por consulta y por
-- tabla, que taparía la diferencia entre 1 día y 90 días.
-- "Charges are rounded up to the nearest MB, with a minimum 10 MB data processed per table referenced by the
-- query, and with a minimum 10 MB data processed per query." https://cloud.google.com/bigquery/pricing

-- [1] UN DÍA. Filtro constante sobre la columna de partición: debe leer 1 partición.
SELECT tipo, COUNT(*) AS operaciones, SUM(importe) AS neto
FROM `sdag-lab-000000.banca.transacciones`
WHERE fecha = DATE '2026-07-15'
GROUP BY tipo
ORDER BY operaciones DESC;

-- [2] LOS 90 DÍAS. Misma consulta, rango completo: debe leer 90 particiones.
SELECT tipo, COUNT(*) AS operaciones, SUM(importe) AS neto
FROM `sdag-lab-000000.banca.transacciones`
WHERE fecha BETWEEN DATE '2026-06-01' AND DATE '2026-08-29'
GROUP BY tipo
ORDER BY operaciones DESC;

-- [3] SIN FILTRO DE PARTICIÓN. Debe FALLAR, no leer la tabla entera:
-- "Cannot query over table 'project_id.dataset.table' without a filter that can be used for partition
-- elimination." https://docs.cloud.google.com/bigquery/docs/querying-partitioned-tables (act. 2026-09-03)
SELECT COUNT(*) AS total
FROM `sdag-lab-000000.banca.transacciones`;

-- [4] ANTIPATRÓN: función sobre la columna de partición.
-- EXTRACT no está entre las funciones que podan con granularidad diaria:
-- "Other functions and complex mathematical operations will require a full table scan." (misma página)
-- Sirve además para ver si este filtro satisface require_partition_filter.
SELECT COUNT(*) AS operaciones_julio
FROM `sdag-lab-000000.banca.transacciones`
WHERE EXTRACT(MONTH FROM fecha) = 7;

-- [5] REFERENCIA PARA EL CLUSTERING: una partición, sin filtrar por cuenta.
-- `cuenta_id` va en el SELECT de las dos consultas a propósito: BigQuery cobra por las columnas que lee, así que
-- si solo [6] la leyera, la diferencia de bytes sería por columnas y no por clustering.
SELECT transaccion_id, cuenta_id, ts_operacion, importe
FROM `sdag-lab-000000.banca.transacciones`
WHERE fecha = DATE '2026-07-15';

-- [6] CLUSTERING: misma partición y mismas columnas, filtrando por la primera columna de clustering.
-- Deben leerse menos bytes que en [5]: "Only the scanned blocks are used to calculate the bytes"
-- https://docs.cloud.google.com/bigquery/docs/clustered-tables
SELECT transaccion_id, cuenta_id, ts_operacion, importe
FROM `sdag-lab-000000.banca.transacciones`
WHERE fecha = DATE '2026-07-15'
  AND cuenta_id = 'CU0000123';
