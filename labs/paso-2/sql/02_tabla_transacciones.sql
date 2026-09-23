-- Paso 2 · Tabla de transacciones, particionada por día y con clustering.
--
-- Decisiones:
-- · PARTITION BY fecha: una columna DATE da particiones diarias.
--   "<date_column>. Partition by a DATE column with daily partitions."
--   https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/data-definition-language (act. 2026-09-10)
--   90 días = 90 particiones, lejos del límite: "Each partitioned table can have up to 10,000 partitions."
--   https://docs.cloud.google.com/bigquery/quotas (act. 2026-09-09)
-- · CLUSTER BY cuenta_id, tipo: el análisis típico filtra por cuenta y después por tipo de operación.
--   El orden importa: "The order of clustered columns affects query performance."
--   https://docs.cloud.google.com/bigquery/docs/clustered-tables
-- · require_partition_filter = TRUE: una consulta sin filtro sobre `fecha` falla en lugar de leer toda la tabla.
-- · Sin partition_expiration_days: ver 01_dataset.sql.
-- · PRIMARY KEY ... NOT ENFORCED: documenta la clave, pero BigQuery no la hace cumplir.
--   La unicidad se comprueba en la carga (paso 3).
-- · NUMERIC(12,2): importes con 2 decimales exactos, sin error de coma flotante.
--   "NUMERIC(P[,S]) ... maximum scale range: 0 ≤ S ≤ 9 ... maximum precision range: max(1, S) ≤ P ≤ S + 29"
--   https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/data-types (act. 2026-09-03)
--
-- Sin PII: cuenta_id es un identificador interno sintético, no un IBAN. Clientes y notas de caso, con datos
-- personales sintéticos, llegan tokenizados en el paso 5.

CREATE TABLE IF NOT EXISTS `sdag-lab-000000.banca.transacciones` (
  transaccion_id   STRING        NOT NULL OPTIONS (description = 'Identificador único de la transacción (TX + 10 dígitos)'),
  cuenta_id        STRING        NOT NULL OPTIONS (description = 'Identificador interno sintético de la cuenta (CU + 7 dígitos). No es un IBAN'),
  fecha            DATE          NOT NULL OPTIONS (description = 'Fecha de la operación (UTC). Columna de partición'),
  ts_operacion     TIMESTAMP     NOT NULL OPTIONS (description = 'Instante de la operación'),
  importe          NUMERIC(12,2) NOT NULL OPTIONS (description = 'Importe con signo: negativo = cargo, positivo = abono'),
  divisa           STRING        NOT NULL OPTIONS (description = 'Código ISO 4217'),
  tipo             STRING        NOT NULL OPTIONS (description = 'TARJETA | TRANSFERENCIA | DOMICILIACION | RETIRADA | INGRESO'),
  canal            STRING        NOT NULL OPTIONS (description = 'APP | WEB | TPV | OFICINA | CAJERO | SISTEMA'),
  pais_contraparte STRING        NOT NULL OPTIONS (description = 'Código ISO 3166-1 alfa-2 de la contraparte'),
  PRIMARY KEY (transaccion_id) NOT ENFORCED
)
PARTITION BY fecha
CLUSTER BY cuenta_id, tipo
OPTIONS (
  require_partition_filter = TRUE,
  description = 'Transacciones bancarias sintéticas (generar_transacciones.py, semilla 20260911). 90 días desde 2026-06-01.',
  labels = [('paso', '2'), ('datos', 'sinteticos')]
);
