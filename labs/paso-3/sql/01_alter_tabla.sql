-- Paso 3 · Dos columnas nuevas en la tabla final, para que el MERGE tenga algo que decidir.
--
-- Se añaden NULLABLE por obligación, no por gusto:
-- "If you add new columns to an existing table schema, the columns must be NULLABLE or REPEATED. You cannot add
--  a REQUIRED column to an existing table schema."
-- https://docs.cloud.google.com/bigquery/docs/managing-table-schemas (act. 2026-09-03)
--
-- Las 1.957.639 filas que ya existen se quedan con NULL en las dos:
-- "NULL if the new column was added with NULLABLE mode. This is the default mode."
-- https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/data-definition-language (act. 2026-09-10)
--
-- Eso obliga a que el MERGE trate el NULL: `S.updated_at > T.updated_at` es NULL cuando T.updated_at es NULL,
-- y una condición NULL no entra en el WHEN MATCHED. Ver 03_merge.sql.

ALTER TABLE `sdag-lab-000000.banca.transacciones`
  ADD COLUMN IF NOT EXISTS estado STRING
    OPTIONS (description = 'PENDIENTE | LIQUIDADA | DEVUELTA. NULL en las filas cargadas en el paso 2'),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP
    OPTIONS (description = 'Última modificación en el origen. Es el criterio del MERGE para decidir si actualiza');
