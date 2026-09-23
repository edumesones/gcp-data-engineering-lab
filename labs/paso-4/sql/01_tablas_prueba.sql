-- Paso 4 · Las dos tablas que hacen comparable el criterio.
--
-- El criterio del diseño es "un backfill de tres días produce el mismo resultado que tres ejecuciones diarias".
-- Para poder compararlo hacen falta dos destinos idénticos y vacíos: uno lo llena el DAG ejecutándose día a día,
-- el otro el mismo DAG lanzado como backfill. Al final se comparan filas y huella de contenido.
--
-- Por qué no se usa `banca.transacciones`: para comparar habría que vaciar particiones entre pruebas, que es DML
-- que muta y cuesta, o tirar de time travel. Dos tablas de prueba dejan una evidencia más limpia y no tocan los
-- 2 M de filas de los pasos 2 y 3.
--
-- Mismo particionado, clustering y filtro obligatorio que la tabla real: si el destino no se comporta igual, la
-- prueba no demuestra nada del pipeline de verdad.
-- Las dos llevan expiración: son tablas de un experimento, no del pipeline.

CREATE OR REPLACE TABLE `sdag-lab-000000.banca.p4_diario` (
  transaccion_id   STRING        NOT NULL,
  cuenta_id        STRING        NOT NULL,
  fecha            DATE          NOT NULL,
  ts_operacion     TIMESTAMP     NOT NULL,
  importe          NUMERIC(12,2) NOT NULL,
  divisa           STRING        NOT NULL,
  tipo             STRING        NOT NULL,
  canal            STRING        NOT NULL,
  pais_contraparte STRING        NOT NULL,
  estado           STRING,
  updated_at       TIMESTAMP,
  PRIMARY KEY (transaccion_id) NOT ENFORCED
)
PARTITION BY fecha
CLUSTER BY cuenta_id, tipo
OPTIONS (
  require_partition_filter = TRUE,
  expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 168 HOUR),
  description = 'Paso 4: destino de las tres ejecuciones diarias. Expira a los 7 días.',
  labels = [('paso', '4'), ('tipo', 'prueba')]
);

CREATE OR REPLACE TABLE `sdag-lab-000000.banca.p4_backfill` (
  transaccion_id   STRING        NOT NULL,
  cuenta_id        STRING        NOT NULL,
  fecha            DATE          NOT NULL,
  ts_operacion     TIMESTAMP     NOT NULL,
  importe          NUMERIC(12,2) NOT NULL,
  divisa           STRING        NOT NULL,
  tipo             STRING        NOT NULL,
  canal            STRING        NOT NULL,
  pais_contraparte STRING        NOT NULL,
  estado           STRING,
  updated_at       TIMESTAMP,
  PRIMARY KEY (transaccion_id) NOT ENFORCED
)
PARTITION BY fecha
CLUSTER BY cuenta_id, tipo
OPTIONS (
  require_partition_filter = TRUE,
  expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 168 HOUR),
  description = 'Paso 4: destino del backfill de los mismos tres días. Expira a los 7 días.',
  labels = [('paso', '4'), ('tipo', 'prueba')]
);
