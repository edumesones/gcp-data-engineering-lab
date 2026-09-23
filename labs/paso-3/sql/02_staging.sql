-- Paso 3 · Tabla de staging de la tanda.
--
-- Por qué existe: el fichero se carga primero aquí y solo después entra en la tabla final con un MERGE. Así la
-- tabla final nunca ve filas a medio validar, y el load job es atómico:
-- "The result of a BigQuery load job is atomic; either all records get inserted or none do."
-- https://docs.cloud.google.com/bigquery/docs/batch-loading-data (act. 2026-09-03)
--
-- Decisiones:
-- · **Una staging por tanda**, con nombre determinista. Relanzar la misma tanda sobrescribe la misma tabla en
--   lugar de acumular basura. Con varias tandas en paralelo haría falta una por intervalo.
-- · **Sin particionar y sin require_partition_filter**: es una tabla de paso, pequeña y de un solo uso.
-- · **Todas las columnas NULLABLE**, al contrario que la tabla final: las filas de corrección solo traen la
--   clave, el estado y el updated_at, y el resto llega vacío. Con columnas REQUIRED, la carga fallaría.
-- · **Expira a las 48 horas**, con el patrón documentado:
--   "expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 48 HOUR)"
--   https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/data-definition-language (act. 2026-09-10)
--
-- ⚠️ Ojo al cargar con `bq load --replace`: WRITE_TRUNCATE "overwrites the data, removes the constraints and uses
-- the schema from the load job" (https://docs.cloud.google.com/bigquery/docs/reference/rest/v2/Job, act.
-- 2026-09-01). Sobre una staging da igual; sobre la tabla final te cambia el esquema sin avisar.

CREATE OR REPLACE TABLE `sdag-lab-000000.banca.stg_transacciones_tanda1` (
  transaccion_id   STRING,
  cuenta_id        STRING,
  fecha            DATE,
  ts_operacion     TIMESTAMP,
  importe          NUMERIC(12,2),
  divisa           STRING,
  tipo             STRING,
  canal            STRING,
  pais_contraparte STRING,
  estado           STRING,
  updated_at       TIMESTAMP
)
OPTIONS (
  expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 48 HOUR),
  description = 'Staging de la tanda 1 del paso 3. Se borra sola a las 48 h.',
  labels = [('paso', '3'), ('tipo', 'staging')]
);
