# Paso 4 · Airflow que orquesta la ingesta

Airflow **2.11.1** en Docker, la misma versión que la imagen por defecto del Airflow gestionado de Google
(Managed Service for Apache Airflow, antes Cloud Composer). **No se crea ningún entorno gestionado**: cobra por el
tiempo que el entorno existe, ejecute DAGs o no.

**Dónde corrió:** en un servidor propio con Docker (`vps-b`), no en el portátil, en **un solo contenedor**
con `airflow db migrate && airflow scheduler`. El compose oficial pide *"At least 4GB of memory"*, y
`airflow standalone` murió por falta de memoria con 2 GiB.

## Qué hay aquí

| Fichero | Qué es |
|---|---|
| `dags/sdag_ingesta_diaria.py` | El DAG: esperar fichero → staging del día → validar → MERGE → comprobar |
| `remoto/docker-compose.yaml` | **El que se usó.** Un contenedor, sin webserver, sin puertos publicados, 2 GiB, ADC en solo lectura |
| `remoto/desplegar.sh` · `remoto/limpiar.sh` | Copian compose, DAG y ADC al servidor y arrancan / paran y borran las credenciales (`shred`) |
| `sql/01_tablas_prueba.sql` | `banca.p4_diario` y `banca.p4_backfill`: vacías, particionadas, expiran en 7 días |
| `sql/02_comparar.sql` | La comparación del criterio: resumen con huella, `EXCEPT DISTINCT` en los dos sentidos, filas por día |
| `data/` | Tres días sintéticos (2026-09-02 a 09-04, 70.817 filas) y su manifiesto |
| `evidencia_*.json` · `evidencia_logs/` | Historial de Airflow, jobs de BigQuery, comparación y logs del backfill |
| `docker-compose.yaml` · `docker-compose.override.yaml` · `.env` | Intento local con el compose oficial. **Descartado** (el portátil no lo soporta); se conservan sin usar |

## Secuencia que se ejecutó (2026-09-14)

**0. Credenciales** (paso manual: abre el navegador). No se crea ninguna clave de cuenta de servicio:

```
gcloud auth application-default login --impersonate-service-account=sdag-pipeline@sdag-lab-000000.iam.gserviceaccount.com
```

**1. Desplegar y arrancar:** `HOST=vps-b bash labs/paso-4/remoto/desplegar.sh`

**2. Camino diario → `p4_diario`:** tres ejecuciones manuales (`airflow dags trigger sdag_ingesta_diaria -e 2026-09-0X`).

**3. Recrear el contenedor** (`docker compose up -d --force-recreate`, base SQLite nueva) **antes del backfill**.
En Airflow 2, `dag_run` tiene una clave única `(dag_id, execution_date)`. Un backfill sobre fechas que ya tienen
ejecución **la reutiliza**: con las tareas ya en `success`, no ejecuta nada y dice *"succeeded: 15"*. Pasó una vez y
dejó `p4_backfill` vacía.

**4. Backfill → `p4_backfill`**, desacoplado dentro del contenedor, con el DAG en pausa:

```
airflow dags backfill -s 2026-09-02 -e 2026-09-04 -c '{"destino": "p4_backfill"}' sdag_ingesta_diaria
```

**5. Comparar:** las tres consultas de `sql/02_comparar.sql`.

**6. Relanzar los dos caminos** (criterio 5): `dags backfill … --reset-dagruns -y`, y manuales a mediodía para el
diario, porque las 00:00 ya las ocupa `backfill__<día>`. El DAG solo usa `ds`.

**7. Limpiar:** `HOST=vps-b SSH=ssh bash labs/paso-4/remoto/limpiar.sh`

## Por qué el DAG es así

- **Todo sale de la fecha lógica (`ds`)**, nunca de `now()` (*"should never be used inside a task"*). Tampoco de
  `data_interval_start`: una ejecución manual recibe el intervalo que **termina** en su fecha, y la del día 3 cargó
  el fichero del día 2.
- **El MERGE es la idempotencia.** Relanzar un día toca 0 filas.
- **`force_rerun=True`, con un id legible** (`sdag_p4r3_<destino>_<día>_t<intento>` + sufijo aleatorio). Con un id
  determinista, cada relanzamiento fallaba con *"already exists and is in DONE state"*. Añadir `DONE` a
  `reattach_states` no lo arregla en el provider 19.5.0: el código lanza *"Job is already in state DONE. Can not
  reattach to this job."*
- **`end_date` a las 23:59:59 del último día.** Con las 00:00, una ejecución manual de ese día a mediodía terminaba
  en `success` sin ninguna tarea.
- **`write_disposition="WRITE_TRUNCATE"`** en la staging: reintentar reescribe, no falla (el `WRITE_EMPTY` por
  defecto sí fallaría).
- **`autodetect=False` con esquema explícito**: el operador trae `autodetect=True` por defecto.
- **`catchup=False` y `max_active_runs=1`**: el backfill se lanza a mano y los días van de uno en uno.
- **Conexión `google_cloud_default` vacía por variable de entorno** (`google-cloud-platform://`): usa ADC. Sin ella,
  `db migrate` no crea la conexión y los hooks fallan.
