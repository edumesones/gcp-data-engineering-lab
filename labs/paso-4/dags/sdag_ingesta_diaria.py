"""Paso 4 · DAG diario que orquesta la ingesta de los pasos 2 y 3.

Por cada intervalo de datos (un día):
    esperar el fichero en GCS -> cargar a una staging del día -> validar -> MERGE al destino -> comprobar

Tres cosas que hacen que un backfill dé lo mismo que las ejecuciones diarias:

1. **Todo depende de la fecha lógica, nunca del reloj.** Las rutas, el nombre de la staging y las fechas del MERGE
   salen de `ds` / `ds_nodash`. La documentación de Airflow es explícita con el reloj:
   "This function should never be used inside a task, especially to do the critical computation, as it leads to
   different outcomes on each run."
   https://airflow.apache.org/docs/apache-airflow/2.11.1/best-practices.html

   Por qué `ds` y no `data_interval_start` (comprobado el 2026-09-14 en este laboratorio, Airflow 2.11.1):
   con horario cron, en una ejecución programada o de backfill la fecha lógica coincide con el inicio del
   intervalo; pero una ejecución **manual** (`airflow dags trigger -e 2026-09-02`) recibió el intervalo que
   **termina** en esa fecha (2026-09-01 -> 2026-09-02). Con `data_interval_start`, el sensor de esa ejecución
   esperaba `dt=2026-09-01` y la del día 3 cargó el fichero del día 2. Con la fecha lógica, los dos caminos
   procesan el mismo día.

2. **La escritura final es un MERGE por clave**, no un INSERT:
   "Do not use INSERT during a task re-run ... Replace it with UPSERT." (misma página)

3. **Job id legible y único por intento** (`force_rerun=True`). La idempotencia la da el MERGE, no el id del job.
   Un id determinista (`force_rerun=False`) se probó y se descartó el 2026-09-14; ver el comentario de la tarea.
   https://airflow.apache.org/docs/apache-airflow-providers-google/stable/_api/airflow/providers/google/cloud/operators/bigquery/index.html

El destino es un parámetro para poder comparar los dos caminos del criterio:
    ejecuciones diarias -> banca.p4_diario
    backfill            -> banca.p4_backfill   (se pasa con --conf '{"destino": "p4_backfill"}')
"""

from __future__ import annotations

from datetime import datetime, timedelta

from airflow import DAG
from airflow.providers.google.cloud.operators.bigquery import (
    BigQueryCheckOperator,
    BigQueryInsertJobOperator,
)
from airflow.providers.google.cloud.sensors.gcs import GCSObjectExistenceSensor
from airflow.providers.google.cloud.transfers.gcs_to_bigquery import GCSToBigQueryOperator

PROYECTO = "sdag-lab-000000"
DATASET = "banca"
BUCKET = "sdag-lab-000000-landing"
UBICACION = "US"

# Ruta del objeto y nombre de la staging: los dos derivados de la fecha lógica.
OBJETO = "p4/transacciones/dt={{ ds }}/parte-000.csv"
STAGING = f"{DATASET}.stg_p4_{{{{ ds_nodash }}}}"

COLUMNAS = [
    "transaccion_id", "cuenta_id", "fecha", "ts_operacion", "importe",
    "divisa", "tipo", "canal", "pais_contraparte", "estado", "updated_at",
]

ESQUEMA_STAGING = [
    {"name": "transaccion_id", "type": "STRING"},
    {"name": "cuenta_id", "type": "STRING"},
    {"name": "fecha", "type": "DATE"},
    {"name": "ts_operacion", "type": "TIMESTAMP"},
    {"name": "importe", "type": "NUMERIC"},
    {"name": "divisa", "type": "STRING"},
    {"name": "tipo", "type": "STRING"},
    {"name": "canal", "type": "STRING"},
    {"name": "pais_contraparte", "type": "STRING"},
    {"name": "estado", "type": "STRING"},
    {"name": "updated_at", "type": "TIMESTAMP"},
]

# El MERGE filtra por el día en el ON: poda el destino y, comprobado en el paso 3, satisface
# require_partition_filter.
MERGE = f"""
MERGE `{PROYECTO}.{DATASET}.{{{{ params.destino }}}}` AS T
USING (
  SELECT * EXCEPT (rn)
  FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY transaccion_id ORDER BY updated_at DESC) AS rn
    FROM `{PROYECTO}.{STAGING}`
    WHERE fecha = DATE '{{{{ ds }}}}'
  )
  WHERE rn = 1
) AS S
ON  T.transaccion_id = S.transaccion_id
AND T.fecha = DATE '{{{{ ds }}}}'
WHEN MATCHED AND (T.updated_at IS NULL OR S.updated_at > T.updated_at) THEN
  UPDATE SET estado = S.estado, updated_at = S.updated_at
WHEN NOT MATCHED THEN
  INSERT ({", ".join(COLUMNAS)})
  VALUES ({", ".join(f"S.{c}" for c in COLUMNAS)})
"""

with DAG(
    dag_id="sdag_ingesta_diaria",
    description="Paso 4: GCS -> staging -> MERGE, un día por ejecución",
    start_date=datetime(2026, 9, 2),
    # end_date acota el DAG a los tres días del laboratorio. Sin él, al despausarlo el scheduler crearía una
    # ejecución para el intervalo más reciente (días después), que esperaría un fichero inexistente.
    # 23:59:59 y no 00:00 (2026-09-14): con end_date=2026-09-04 00:00, una ejecución manual con fecha lógica
    # 2026-09-04T12:00 quedó en `success` SIN NINGUNA tarea. Airflow no crea instancias de las tareas cuya fecha
    # lógica cae fuera de su end_date, y la ejecución vacía se da por buena. Las ejecuciones programadas y de
    # backfill no cambian: la última sigue siendo la del 2026-09-04 00:00.
    end_date=datetime(2026, 9, 4, 23, 59, 59),
    schedule="@daily",
    # catchup=False a propósito: el backfill se lanza a mano, para que la comparación del criterio sea explícita.
    catchup=False,
    max_active_runs=1,
    params={"destino": "p4_diario"},
    default_args={
        "retries": 2,
        "retry_delay": timedelta(minutes=1),
        "project_id": PROYECTO,
    },
    tags=["sdag", "paso-4"],
) as dag:

    esperar_fichero = GCSObjectExistenceSensor(
        task_id="esperar_fichero",
        bucket=BUCKET,
        object=OBJETO,
        poke_interval=15,
        timeout=300,
        mode="reschedule",  # libera el worker entre comprobaciones
    )

    cargar_staging = GCSToBigQueryOperator(
        task_id="cargar_staging",
        bucket=BUCKET,
        source_objects=[OBJETO],
        destination_project_dataset_table=f"{PROYECTO}.{STAGING}",
        schema_fields=ESQUEMA_STAGING,   # explícito: autodetect=True es el valor por defecto y adivina tipos
        autodetect=False,
        skip_leading_rows=1,
        source_format="CSV",
        # WRITE_TRUNCATE, no el WRITE_EMPTY por defecto: reintentar debe reescribir la staging, no fallar.
        write_disposition="WRITE_TRUNCATE",
        create_disposition="CREATE_IF_NEEDED",
        location=UBICACION,
    )

    validar_staging = BigQueryCheckOperator(
        task_id="validar_staging",
        sql=f"""
        SELECT
          COUNTIF(transaccion_id IS NULL) = 0,
          COUNTIF(fecha <> DATE '{{{{ ds }}}}') = 0,
          COUNT(*) > 0
        FROM `{PROYECTO}.{STAGING}`
        """,
        use_legacy_sql=False,
        location=UBICACION,
    )

    merge = BigQueryInsertJobOperator(
        task_id="merge_al_destino",
        configuration={
            "query": {
                "query": MERGE,
                "useLegacySql": False,
            }
        },
        location=UBICACION,
        # Id único por intento: prefijo legible (destino, día, intento) + sufijo aleatorio del operador.
        # "force_rerun (bool) - If True then operator will use hash of uuid as job id suffix" (página de arriba).
        #
        # Por qué NO un id determinista (force_rerun=False), comprobado el 2026-09-14 con el provider 19.5.0:
        # · El sufijo sería el hash de la configuración, y el id de un job terminado sigue ocupado en el historial
        #   de BigQuery. Todo relanzamiento del mismo día falla con "Job with id: … already exists and is in DONE
        #   state". Pasó dos veces: con un MERGE mal fechado, y al relanzar un backfill ya correcto (la tabla no
        #   cambió, pero la tarea y la ejecución quedaron en failed, y los retries no sirven para nada).
        # · Añadir DONE a reattach_states tampoco lo arregla. El código de `execute` hace
        #   `if job.state == "DONE": raise AirflowException("Job is already in state DONE. Can not reattach to this job.")`
        # · Lo único que protegía (no lanzar un segundo MERGE mientras el primero sigue RUNNING) apenas importa
        #   aquí: el MERGE es idempotente (paso 3) y el DAG tiene max_active_runs=1.
        job_id="sdag_p4r3_{{ params.destino }}_{{ ds_nodash }}_t{{ ti.try_number }}",
        force_rerun=True,
    )

    comprobar_destino = BigQueryCheckOperator(
        task_id="comprobar_destino",
        sql=f"""
        SELECT
          COUNT(*) > 0,
          COUNT(*) = COUNT(DISTINCT transaccion_id)
        FROM `{PROYECTO}.{DATASET}.{{{{ params.destino }}}}`
        WHERE fecha = DATE '{{{{ ds }}}}'
        """,
        use_legacy_sql=False,
        location=UBICACION,
    )

    esperar_fichero >> cargar_staging >> validar_staging >> merge >> comprobar_destino
