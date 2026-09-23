-- Paso 2 · Rol de datos para la cuenta de servicio, SOLO sobre el dataset `banca`.
-- Lo ejecuta el autor (Owner). Quien concede necesita bigquery.datasets.update.
--
-- "GRANT `ROLE_LIST` ON SCHEMA RESOURCE_NAME TO "USER_LIST""
-- https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/data-control-language (act. 2026-09-03)
--
-- No se usa `bq add-iam-policy-binding`: "does not support datasets".
-- Tampoco `bq update --source`: "the existing access controls are overwritten".
-- https://docs.cloud.google.com/bigquery/docs/control-access-to-resources-iam (act. 2026-09-03)
--
-- Con jobUser en el proyecto (paso 1) y dataEditor aquí, la cuenta puede crear y cargar tablas y consultarlas en
-- este dataset, y en ningún otro.

GRANT `roles/bigquery.dataEditor`
ON SCHEMA `sdag-lab-000000.banca`
TO "serviceAccount:sdag-pipeline@sdag-lab-000000.iam.gserviceaccount.com";
