-- Paso 2 · Dataset del laboratorio.
-- Lo ejecuta el autor (Owner), no la cuenta de servicio: crear datasets no está entre sus roles.
--
-- Ubicación: US (multirregión), decidida por el autor el 2026-09-11. No se puede cambiar después:
-- "You cannot change the name of an existing dataset or relocate a dataset after it's created."
-- https://docs.cloud.google.com/bigquery/docs/managing-datasets (act. 2026-09-03)
-- Motivo: el bucket del paso 3 puede ir en us-central1, que está colocado con la multirregión US y además
-- tiene nivel gratuito de Cloud Storage (5 GB, solo en us-east1, us-west1 y us-central1).
--
-- Sin default_table_expiration_days ni default_partition_expiration_days, a propósito.
-- La expiración de partición se calcula desde la fecha de la partición, y los datos sintéticos son de
-- jun-ago 2026: "Existing partitions expire immediately if they are older than the new expiration time."
-- https://docs.cloud.google.com/bigquery/docs/managing-partitioned-tables (act. 2026-09-03)

CREATE SCHEMA IF NOT EXISTS `sdag-lab-000000.banca`
OPTIONS (
  location = 'US',
  description = 'Laboratorio sensitive-data-agent-gcp. Datos bancarios sintéticos, sin PII.',
  labels = [('proyecto', 'sdag'), ('datos', 'sinteticos')]
);
