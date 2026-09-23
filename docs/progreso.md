# Progreso

> Actualizado el 2026-09-11 al pasar el trabajo a una sesión nueva en esta carpeta.
> **Lee primero la sección "Siguiente paso".**

## Siguiente paso

> **Dónde estamos (2026-09-14, 11:10 UTC): cerrando el paso 4.**
> - **Laboratorio hecho.** El backfill da lo mismo que las diarias y relanzar no cambia nada: sección E.
> - **Verificador independiente en marcha** con el criterio enmendado (el autor lo aprobó el 2026-09-14).
> - **Airflow apagado** y credenciales borradas del servidor.
> - **Diagrama** `diagramas/paso-4.html` hecho.
> - **Lección 0004** en borrador, a la espera del veredicto.
>
> **Al volver:**
> 1. Leer `verificacion/4-2026-09-14.md`. Si no da PASA, corregir y lanzar **otro** verificador.
> 2. Terminar la lección 0004 y pasarle su propio verificador.
> 3. Paso 5: antes de lanzar nada en Dataflow, consultar los precios de Dataflow y SDP.

### Paso 1 del laboratorio

**Hecho el 2026-09-11:**

- Login personal hecho. `sdag-lab` → cuenta `you@example.com`, proyecto `sdag-lab-000000`.
  La configuración `default` de la máquina sigue activa a nivel global, sin tocar.
- Cuenta de facturación `XXXXXX-XXXXXX-XXXXXX`, **EUR**. Tiene otros 3 proyectos personales con facturación
  activa → el presupuesto se limita al proyecto del laboratorio.
- Proyecto **`sdag-lab-000000`** (número `000000000000`, sin organización) creado y asociado a esa facturación.
- API `billingbudgets.googleapis.com` activada (la exige `gcloud billing budgets create`).
- **Presupuesto `sdag-lab-1EUR`** (id `00000000-0000-0000-0000-000000000000`): 1 EUR mensual, solo este proyecto,
  **excluye créditos**, avisos al 50/90/100 % real y 100 % previsto, destinatarios IAM por defecto.

**Decisión del autor (2026-09-11): aviso + cuota de BigQuery, sin corte automático.** Motivo, con la documentación:
- Un presupuesto **solo avisa**, no corta, y tarda horas ([budgets](https://docs.cloud.google.com/billing/docs/how-to/budgets), act. 2026-09-03).
- El *spend cap* (Preview) solo cubre Gemini API, Agent Platform, Cloud Run y Cloud Run functions: no BigQuery,
  Storage, KMS ni SDP ([spend caps](https://docs.cloud.google.com/billing/docs/how-to/budgets-spend-caps), act. 2026-09-10).
- Quitar la facturación automáticamente *"might irretrievably delete"* recursos y no para justo en el tope
  ([disable billing](https://docs.cloud.google.com/billing/docs/how-to/disable-billing-with-notifications), act. 2026-09-03).
- **Paso 2:** fijar la cuota `QueryUsagePerDay` de BigQuery (solo on-demand, aproximada, se fija en la consola)
  ([custom quotas](https://docs.cloud.google.com/bigquery/docs/custom-quotas), act. 2026-09-03).
- Por defecto el presupuesto descuenta los créditos, y con crédito de prueba nunca avisaría → `EXCLUDE_ALL_CREDITS`
  ([Budget API](https://docs.cloud.google.com/billing/docs/reference/budget/rest/v1/billingAccounts.budgets)).

**Coste previsto (consultado el 2026-09-11):**
- Nivel gratuito: BigQuery 1 TiB de consulta y 10 GiB de almacenamiento al mes; Storage 5 GB **solo en us-east1,
  us-west1 y us-central1** ([free tier](https://docs.cloud.google.com/free/docs/free-cloud-features)).
- SDP: el primer GiB al mes es gratis, tanto al inspeccionar como al transformar
  ([SDP pricing](https://cloud.google.com/sensitive-data-protection/pricing)).
- KMS no es gratis: clave SOFTWARE a $0.000082192 por hora (≈ 0,06 $ al mes), más $0.03 por cada 10k operaciones
  ([KMS pricing](https://cloud.google.com/kms/pricing)).
- Pasos 7–8 (Gemini): ⚠️ sin calcular.

**Tropiezos (para la lección):**
- `gcloud billing budgets create` devuelve `INVALID_ARGUMENT` si el proyecto del filtro **aún no está asociado** a
  la cuenta de facturación, tanto con el ID como con el número. Asociado primero, funciona.
  Observado, no documentado.
- En PowerShell, `--threshold-rule=percent=1.00,basis=forecasted-spend` hay que ponerlo entre comillas: la coma lo
  convierte en array.
- El proyecto recién creado ya trae activas APIs de BigQuery, Storage, Dataplex, Logging, etc.
  (`gcloud services list --enabled`). Sin recursos creados no gastan.

**Falta para cerrar el paso 1:**
1. Cuenta de servicio de mínimo privilegio. **Roles listados, aprobados por el autor el 2026-09-11 antes de crearla:**

   | Quién | Rol | Dónde |
   |---|---|---|
   | `sdag-pipeline@sdag-lab-000000.iam.gserviceaccount.com` | `roles/bigquery.jobUser` | proyecto `sdag-lab-000000` (nivel mínimo posible) |
   | `user:you@example.com` | `roles/iam.serviceAccountTokenCreator` | **solo** sobre la cuenta `sdag-pipeline`, no en el proyecto |

   - La cuenta de servicio **no aparece con ningún otro rol** en la política IAM del proyecto.
   - **Cero claves gestionadas por el usuario.**
   - Los roles de datos (`bigquery.dataEditor` y el del bucket) llegan en el paso 2, **a nivel de dataset y de bucket**.

   Fuentes (consultadas el 2026-09-11):
   [BigQuery access control](https://docs.cloud.google.com/bigquery/docs/access-control) ·
   [impersonation](https://docs.cloud.google.com/iam/docs/service-account-impersonation) ·
   [best practices SA](https://docs.cloud.google.com/iam/docs/best-practices-service-accounts)

   ⚠️ No se aplica la política de organización que bloquea crear claves: el proyecto no tiene organización.
   Sin confirmar si puede fijarse a nivel de proyecto sin organización.

   **Hecho el 2026-09-11:** APIs `iam` e `iamcredentials` activadas, cuenta `sdag-pipeline` creada y los dos
   permisos concedidos. La impersonación falló con `PERMISSION_DENIED` justo después de conceder el permiso
   y funcionó unos minutos más tarde: la propagación de IAM es *"Typically 2 minutes, potentially 7 minutes or
   longer"* ([propagation](https://docs.cloud.google.com/iam/docs/access-change-propagation), act. 2026-09-10).
   Uso: `gcloud ... --impersonate-service-account=sdag-pipeline@sdag-lab-000000.iam.gserviceaccount.com`.
2. ✅ Verificación independiente → `verificacion/1-2026-09-11.md`: **PASA**. Hallazgos que no afectan al criterio:
   - ✅ **`bq` no arrancaba** (`AttributeError: module 'absl.flags' has no attribute 'FLAGS'`). **Arreglado el 2026-09-11.**
     Causa: 13 carpetas del Cloud SDK (`platform\bq\third_party\*` y `platform\gsutil`) sin permiso de lectura para
     los usuarios. Python veía `absl/flags` como un paquete vacío. No era un problema de versiones.
     Arreglo, con el autor aceptando el UAC: `takeown /R /A /D S` + `icacls /reset /T` en `platform\bq` y `platform\gsutil`.
     Comprobado: 0 carpetas ilegibles; `bq version` 2.1.29; `bq ls` y `bq query --dry_run "SELECT 1"` con exit 0;
     `gsutil version` 5.36. En gsutil, `icacls` no pudo con 6 ficheros de ruta demasiado larga.
     Hay actualización del SDK disponible (560 → 584) sin aplicar.
   - En la cuenta de facturación hay otro presupuesto anterior, `Alerta cero gasto - Gemini API`, sobre toda la
     cuenta y con `INCLUDE_ALL_CREDITS`. No es del laboratorio y no se ha tocado. Decidir con el autor.
   - `roles/owner` no incluye `iam.serviceAccounts.getAccessToken`: la impersonación funciona por el permiso
     concedido sobre la cuenta de servicio, no por ser Owner.
3. Lección: **borrador** en `0001-el-presupuesto-no-es-un-freno.md`,
   preparado mientras corría el verificador, a petición del autor. Lleva aviso de borrador. Falta:
   - el PASA del laboratorio;
   - una verificación propia de la lección contra la documentación, con otro subagente nuevo.
   - 1.ª verificación de la lección (`verificacion/1-leccion-2026-09-11.md`): **PASA CON RESERVAS**. Cuatro puntos
     de gravedad media, todos corregidos:
     - roles de datos concedibles también sobre tabla, vista o rutina;
     - la cita de "several hours" estaba fuera de contexto;
     - "sin roles básicos" ignoraba que el usuario es Owner;
     - "APIs sin recursos no cuestan" no tenía fuente.

   - 2.ª verificación (`1-leccion-v2-2026-09-11.md`): **PASA CON RESERVAS**, todo de trazabilidad de citas. Corregido.
   - 3.ª verificación (`1-leccion-v3-2026-09-11.md`): **PASA**. Solo 6 hallazgos de gravedad baja, también corregidos.
     **Paso 1 cerrado el 2026-09-11.**
   - ⚠️ **Hallazgo que afecta al presupuesto del laboratorio:** algunos servicios aplican su nivel gratuito como
     crédito. Con `EXCLUDE_ALL_CREDITS`, el presupuesto de 1 € podría contar a precio bruto uso que es gratis y
     avisar sin gasto real. Sin confirmar qué servicios lo hacen. Solo afecta a avisos, no a cobros. Decidir con el autor.
4. ✅ Diagrama: `diagramas/paso-1.html`, generado con archify desde `diagramas/paso-1.architecture.json`.
   Validación showcase: 9/9 comprobaciones, 0 errores, 0 avisos. Sin desbordes a 1440×900, 1600×1000,
   1920×1080 ni 2048×1320. Capturas revisadas a mano en claro y oscuro. Detalle estético sin corregir: franja
   vacía abajo a 2048×1320. La interfaz del visor sale en inglés (archify no tiene locale `es`).

### C · Paso 2 del laboratorio — **cerrado el 2026-09-12, salvo el criterio 6**

> Solo falta anotar el valor de la cuota `QueryUsagePerDay` que el autor fijó en la consola. No se puede leer con
> este gcloud: `gcloud beta` no está instalado y instalarlo pide permisos de administrador.
> **Siguiente paso del laboratorio: paso 3** (ingesta incremental idempotente; el criterio es que relanzar la
> misma carga dos veces no duplique filas). Material base: `05_deep_ingesta_bigquery_airflow.md`.

**Decidido por el autor (2026-09-11):**
- En el paso 2 se carga **solo `transacciones`**, sin PII. Clientes y notas de caso entran tokenizados en el paso 5.
- Volumen: **90 días, ~2M filas**.

**Hecho:**
- `labs/paso-2/generar_transacciones.py`: solo librería estándar, semilla 20260911, determinista (dos ejecuciones
  dan el mismo SHA-256). Genera 1.957.639 filas, 172,8 MB, del 2026-06-01 al 2026-08-29.
  SHA-256 del CSV: `c38db624…810f`. `manifiesto.json` guarda las filas por día. `data/` está en `.gitignore`.
- SQL preparado, **sin ejecutar**:
  - `01_dataset.sql`: dataset `banca`, **ubicación pendiente**.
  - `02_tabla_transacciones.sql`: `PARTITION BY fecha`, `CLUSTER BY cuenta_id, tipo`,
    `require_partition_filter`, sin expiración de partición.
  - `03_permiso_dataset.sql`: `GRANT dataEditor ON SCHEMA` para `sdag-pipeline`.

**Hallazgos de la documentación que condicionan el diseño** (investigación del 2026-09-11, con citas):
- **La ubicación no se puede cambiar después.** Colocación para el paso 3:
  - dataset en US → bucket en `us-central1`, que además tiene nivel gratuito de Storage;
  - dataset en EU → bucket en `europe-west4`, sin nivel gratuito de Storage.
  - On-demand: $6.25/TiB en US y en EU.
- **Expiración de partición: no poner ninguna.** Se cuenta desde la fecha de la partición, y *"Existing partitions
  expire immediately if they are older than the new expiration time"*. Los datos son de jun-ago 2026.
- **Poda:**
  - `totalPartitionsProcessed` y `totalBytesProcessed` existen en las estadísticas del job.
  - `INFORMATION_SCHEMA.JOBS` no tiene columna de particiones procesadas.
  - Mínimo facturado: 10 MB por consulta y por tabla → comparar `totalBytesProcessed`, no `totalBytesBilled`.
  - El dry run no es exacto con clustering.
- **Permiso sobre el dataset:** `GRANT ... ON SCHEMA`. `bq add-iam-policy-binding` *"does not support datasets"*, y
  `bq update --source` sobrescribe los permisos existentes.
- **Cuota `QueryUsagePerDay`:** documentada solo en la consola, en TiB, por defecto 200 TiB. Sin confirmar: valor
  mínimo, si admite fracciones y el `quota-id` para gcloud.
- **`bq load` local:** gratis. La consola limita a 100 MB y para bq no hay límite documentado (el CSV ocupa 172,8 MB).

**Decisiones del autor (2026-09-11), antes de construir:**
- **Ubicación: `US`** (multirregión). El bucket del paso 3 irá en `us-central1`, que tiene nivel gratuito de Storage.
- **Cuota `QueryUsagePerDay`: el valor mínimo que acepte la consola.** Probar 0,01 TiB; si no admite fracciones, 1 TiB.
  La fija el autor en la consola (IAM y administración → Cuotas).

**Criterio de aceptación del paso 2, aprobado por el autor antes de construir:**

1. El dataset `banca` existe en `US`. `sdag-pipeline` tiene `roles/bigquery.dataEditor` **solo** sobre `banca`, y en
   la política del proyecto sigue teniendo únicamente `roles/bigquery.jobUser`.
2. `banca.transacciones` está particionada por día en `fecha`, con `CLUSTER BY cuenta_id, tipo`,
   `require_partition_filter = TRUE` y **sin** expiración de partición.
3. Tiene 1.957.639 filas en 90 particiones, y las filas por partición coinciden con
   `labs/paso-2/data/manifiesto.json`.
4. Poda comprobada con las estadísticas reales del job:
   - consulta de 1 día → `totalPartitionsProcessed = 1` y `totalBytesProcessed` menor que el 5 % del de la misma
     consulta sobre los 90 días, que da `totalPartitionsProcessed = 90`;
   - se compara `totalBytesProcessed`, no `totalBytesBilled`: hay un mínimo de 10 MB facturados por consulta.
5. Una consulta sin filtro de partición falla con: *"Cannot query over table ... without a filter that can be used
   for partition elimination"*.
6. La cuota `QueryUsagePerDay` del proyecto queda por debajo de los 200 TiB por defecto.

**Impersonación con `bq`: funciona.** Comprobado el 2026-09-11 con
`CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT=sdag-pipeline@… bq ls` (aviso de impersonación y exit 0).
`bq --help` no muestra ningún flag de impersonación: es la variable de entorno de gcloud.
⚠️ Observado, no encontrado en documentación.

**Construido el 2026-09-11:**
- Dataset `sdag-lab-000000:banca` en `US`, con etiquetas y sin expiraciones por defecto.
- `GRANT roles/bigquery.dataEditor ON SCHEMA banca` a `sdag-pipeline`. En el ACL del dataset aparece como
  `"role": "WRITER"` para esa cuenta: es el nombre antiguo del mismo rol.
- Tabla `banca.transacciones` creada **por la cuenta de servicio impersonada**, no por el Owner. `bq show` confirma:
  `timePartitioning {field: fecha, type: DAY, requirePartitionFilter: true}`, `clustering [cuenta_id, tipo]`,
  `tableConstraints.primaryKey [transaccion_id]` y las 9 columnas en modo `REQUIRED` (el `NOT NULL` del DDL).
- Carga del CSV de 172,8 MB con `bq load` local, también impersonando. 1 min 19 s, exit 0.
  El `bq load` local funciona con 172,8 MB: el límite de 100 MB que documenta Google es el de la consola.
  El timestamp con sufijo `UTC` se parseó sin problema.
- **Datos contrastados contra el generador** (criterio 3, cumplido): `INFORMATION_SCHEMA.PARTITIONS` da 90
  particiones y 1.957.639 filas, y **ninguna partición difiere** de `manifiesto.json`. Bytes lógicos por
  partición: mín. 1.124.385, máx. 2.394.698, media 1.808.501. Total 162.765.153 bytes.
  Evidencia en `labs/paso-2/particiones.json`.
- **Poda medida con las estadísticas del job** (criterios 4 y 5, cumplidos). Ejecutado por la cuenta de servicio
  impersonada, con `--nouse_cache`. Evidencia: `labs/paso-2/resultados_poda.json`.

  | Consulta | Particiones | Bytes procesados | Bytes facturados |
  |---|---|---|---|
  | 1 día (`fecha = DATE '2026-07-15'`) | 1 | 966.472 | 10.485.760 |
  | 90 días (`BETWEEN`) | 90 | 68.515.449 | 69.206.016 |

  1 día procesa el **1,41 %** de lo que procesa el rango completo (umbral del criterio: 5 %).
  Facturado: 10.485.760 = 10 MiB exactos, el mínimo por consulta. Por eso el criterio compara lo **procesado**.
- **Sin filtro de partición falla**, con el texto real:
  *"Cannot query over table 'sdag-lab-000000.banca.transacciones' without a filter over column(s) 'fecha' that
  can be used for partition elimination"*. Difiere del que documenta Google (*"without a filter that can be used
  for partition elimination"*): el mensaje real nombra la columna.
- **Hallazgo, antipatrón:** `WHERE EXTRACT(MONTH FROM fecha) = 7` **falla con el mismo error**. Un filtro sobre la
  columna de partición que no permite podar **no satisface** `require_partition_filter`. Cierra el ⚠️ que el deep
  dive 05 dejaba abierto ("sin verificar que un filtro satisfaga require_partition_filter").
- **El clustering casi no reduce nada en este laboratorio.** Medido dos veces, con las mismas columnas en ambas
  consultas (`labs/paso-2/resultados_clustering.json`, `sql/05_clustering_escala.sql`):

  | Alcance | Sin filtro de cuenta | Con `cuenta_id = 'CU0000123'` | Ahorro |
  |---|---|---|---|
  | 1 partición (1,5 MB) | 1.572.459 | 1.572.459 | **0 %** |
  | 90 particiones (112 MB) | 111.585.423 | 107.431.263 | **3,7 %** |

  *(inferencia)* Los bloques *"are adaptively sized based on the size of the table"* y la colocación ocurre
  *"at the level of the storage blocks, and not at the level of individual rows"*
  ([Clustered tables](https://docs.cloud.google.com/bigquery/docs/clustered-tables), act. 2026-09-03): con
  particiones de 1-2 MB no hay bloques que saltarse. Además, el generador reparte las cuentas al azar, así que
  una cuenta aparece en todas partes.
  ⚠️ Ninguna página fija un tamaño mínimo para que el clustering compense. La guía que sí existe va en sentido
  contrario: recomienda clustering **en vez de** particionado cuando las particiones bajarían de ~10 GB.
  **Consecuencia para la lección:** en este laboratorio el clustering está bien puesto pero no se puede
  demostrar con datos de 170 MB. No se venderá como ahorro medido.

**✅ Verificación independiente del paso 2** (`verificacion/2-2026-09-12.md`): **PASA** en los criterios 1 a 5.
El verificador no aceptó mis ficheros: relanzó los jobs con `--nouse_cache` y obtuvo las mismas cifras al byte, y
regeneró los datos con la semilla para comprobar que el manifiesto no estaba amañado. Avisa, fuera de alcance, de
que el clustering no reduce bytes (ya recogido abajo).
**✅ Criterio 6 (cuota): cumplido y verificado.** El autor fijó `QueryUsagePerDay` en **1 TiB**. Comprobado sin
depender de su palabra: `gcloud beta` no está instalado, así que se activó la **Cloud Quotas API** (gratis) y se
leyó por REST con el token de ADC:
`GET cloudquotas.googleapis.com/v1/projects/sdag-lab-000000/locations/global/quotaPreferences`
→ una preferencia, `quotaId: QueryUsagePerDay`, `preferredValue: 1048576`, servicio `bigquery.googleapis.com`.
**El valor va en MiB**: 1.048.576 MiB = 1 TiB exacto. La consola lo pide en TiB y la API lo devuelve en MiB.
**Paso 2 cerrado por completo el 2026-09-12.**

**Diagrama del paso 2:** `diagramas/paso-2.html` (tipo *dataflow*), desde `paso-2.dataflow.json`.
Validación showcase 9/9, 0 errores, 0 avisos; sin desbordes a 1440×900, 1600×1000, 1920×1080 ni 2048×1320.
Costó seis intentos: el error fue añadir controles de ruta manuales (anchos, `labelDy`, `channelX`) en vez de
quitar primero las aristas que estorbaban, que es lo que dice la guía de archify. Se quitaron el flujo
`manifiesto → tabla` y el nodo "Sin poda" (su contenido vive en las tarjetas), y el diagrama pasó de 5 filas a 3.
Revisadas las capturas en claro y oscuro: la leyenda llamaba **"policy / PII"** al trazo rojo discontinuo, que aquí
es `sdag-pipeline → transacciones` (identidad, no PII). Corregido con `meta.legend.entries.security.label` =
"identidad y permisos". En un proyecto de datos sensibles, esa etiqueta por defecto engañaba justo en lo que importa.

**Lección 2** (`0002-lo-que-de-verdad-lee-una-consulta.md`):
1.ª verificación (`verificacion/2-leccion-2026-09-12.md`): **PASA CON RESERVAS**. Ningún dato ni número falso —el
verificador reprodujo las cuatro medidas de clustering y salen idénticas—, pero dos citas colgaban de la página
equivocada y había mezcla de unidades. Corregido:
- *"By default, you are not charged for batch loading…"* es de **Pricing**, no de Batch loading.
- *"does not support datasets"* es de la **referencia del bq CLI**, no de Control access.
- Las citas de on-demand y slots son de **Pricing**, no de Editions.
- Unidades: tamaños en MB decimales; el mínimo facturado se explica aparte (la página dice "10 MB" y la cifra
  real son 10.485.760 bytes, o sea 10 MiB).
2.ª verificación (`verificacion/2-leccion-v2-2026-09-12.md`): **PASA CON RESERVAS**. Las 19 citas ya están en la
página que enlazan y todos los números se reprodujeron. Corregido:
- El límite de 100 MB para ficheros locales iba sin enlace → [Loading local data].
- El ⚠️ "impersonación no documentada" era refutable: la propiedad `auth/impersonate_service_account` está en la
  referencia del bq CLI y gcloud documenta el patrón `CLOUDSDK_SECCION_PROPIEDAD`. Lo único cierto es que
  `bq --help` (v2.1.29) no tiene flag. Reescrito sin ⚠️.
- La cita de "editions y on-demand a la vez" es de **Editions**, no de Pricing.
- `total_logical_bytes` viene en bytes, no en MB.
- La lista de filtros que no podan se atribuye ahora a los ejemplos de la página, sin generalizar de más, y el
  fallo de `EXTRACT` se explica con esa lista más el requisito, no solo con el requisito.
- Dato afinado: de 1 min 19 s de carga, el job duró 7 s; el resto fue la subida del fichero.
3.ª verificación (`verificacion/2-leccion-v3-2026-09-12.md`): **PASA CON RESERVAS**. Las 23 citas están en la
página que enlazan y el verificador reprodujo el error de `EXTRACT` carácter a carácter. Corregido:
- **§5 (media):** las cifras de la tabla de clustering se presentaban como tamaño de partición y son
  `totalBytesProcessed` de consultas de 4 columnas. Por eso "111,6 MB" chocaba con los "163 MB" de §1.
  Ahora la tabla dice qué magnitud es cada cifra; el tamaño real de la tabla es 162.765.153 bytes (162,8 MB).
- El job de carga duró 7,9 s, no 7 s.
- `…/docs/loading-data-local` redirige a `…/docs/batch-loading-data`: se cita ya el destino.
- "Cost controls" se llama hoy "Estimate and control costs".
- Quitados de Fuentes los enlaces que no respaldaban nada del cuerpo (DDL y Quotas).
4.ª verificación (`verificacion/2-leccion-v4-2026-09-12.md`): **PASA**. 12/12 URL a 200 sin redirección, 24/24
citas en la página que enlazan, y cuatro jobs reproducidos que coinciden al byte. Sus cuatro observaciones de
gravedad baja, también aplicadas: el antecedente "la misma página" se nombra explícito; los 2.000 slots no son
un techo duro (*"will temporarily burst beyond this limit"*); el 1 min 19 s se marca como observado en terminal
frente a los 7,9 s del job (`ms_job = 7943`); y la variable de entorno de impersonación va como *(inferencia)*.
**Lección 2 cerrada.**

**Decisión del autor (2026-09-12): el listón sigue siendo PASA.** Se le planteó que la lección 2 necesitó cuatro
rondas (~120-160k tokens de subagente cada una) y que los hallazgos bajaban de gravedad en cada vuelta. Aun así,
un paso no se cierra con reservas: se corrige y se lanza otro verificador nuevo hasta el PASA.

**Tropiezos del paso 2 (para la lección):**
- Repetir una consulta la sirve desde la **caché** y da 0 bytes procesados: para medir hay que usar `--nouse_cache`.
- Comparar bytes entre consultas con **distinta lista de columnas** no mide el clustering: BigQuery cobra por columnas.
  Hubo que reescribir [5] y [6] con las mismas columnas, `cuenta_id` incluida.
- `bq` escribe el aviso de impersonación en stderr y el error de la consulta en stdout.

### D · Paso 3 del laboratorio (en preparación, 2026-09-12)

**Decisiones del autor (2026-09-12), antes de construir:**
- **Bucket de aterrizaje** `sdag-lab-000000-landing` en **`us-central1`** (colocado con la multirregión US y con
  nivel gratuito de Storage).
- **Dos columnas nuevas** en `banca.transacciones`, NULLABLE: `estado` y `updated_at`. Así el MERGE tiene que
  decidir entre actualizar o no, y de paso se practica la evolución de esquema.
- **Tandas:** 3 días nuevos + correcciones sobre días ya cargados + duplicados a propósito dentro de la tanda.

**Criterio de aceptación del paso 3, fijado antes de construir:**

1. Existe el bucket `sdag-lab-000000-landing` en `us-central1` con acceso uniforme. `sdag-pipeline` puede leer
   sus objetos por un rol concedido **sobre el bucket**, y en la política del proyecto **no** tiene ningún rol
   nuevo (sigue solo con `roles/bigquery.jobUser`).
2. `banca.transacciones` tiene `estado` y `updated_at` como NULLABLE, y las 1.957.639 filas anteriores las
   tienen a NULL.
3. La ingesta va en tres fases: ficheros inmutables en `gs://sdag-lab-000000-landing/transacciones/dt=YYYY-MM-DD/`,
   carga a una **tabla de staging por intervalo**, y **MERGE** por `transaccion_id` a la tabla final.
4. **Idempotencia (criterio del diseño):** ejecutar la misma tanda dos veces deja el mismo número de filas y el
   mismo contenido (hash de contenido idéntico), y `transaccion_id` sigue siendo único: 0 duplicados.
5. **Las correcciones se aplican:** para los ids corregidos, la tabla final queda con el `updated_at` más
   reciente y su `estado` nuevo, nunca con el viejo.
6. **Los duplicados dentro de la tanda no rompen el MERGE:** se deduplican antes y no aparece el error
   *"UPDATE/MERGE must match at most one source row for each target row"*.
7. Todo lo ejecuta `sdag-pipeline` impersonada.
8. Evidencia: recuentos y hashes antes y después de cada ejecución, más los job ids.

**⚠️ Duda abierta que este paso debe resolver empíricamente:** si un filtro sobre la columna de partición dentro
del `ON` del MERGE satisface `require_partition_filter`. El deep dive 05 lo dejó como "sin verificar".

**Hecho el 2026-09-12:**
- `labs/paso-3/generar_incremental.py`: genera la tanda con las tres clases de fila (nuevas, correcciones y
  duplicados a propósito), un fichero por día en `data/transacciones/dt=YYYY-MM-DD/`, y
  `manifiesto_incremental.json` con los ids corregidos y los duplicados, para que el verificador los contraste.
  Determinista: comprobado que dos ejecuciones dan el mismo SHA-256 por fichero.
- **Los ids de corrección no se inventan**: se calculan a partir de las filas por día del manifiesto del paso 2.
  Comprobado en BigQuery que los tres ids de una prueba existen **con la fecha exacta** calculada, y que
  `MAX(transaccion_id)` = `TX0001957639` = número de filas. Si esa suposición hubiera sido falsa, el MERGE habría
  insertado en lugar de actualizar y el criterio 5 se habría roto sin avisar.
- **Tanda generada** (semilla 20260912): **57.347 filas en 5 ficheros**, 7,0 MB en total.
  - 57.302 filas nuevas en los días 2026-08-30, 08-31 y 09-01.
  - 40 correcciones repartidas en `dt=2026-08-28` y `dt=2026-08-29`, que son días **ya cargados**. Van en el
    fichero de su propio día porque `fecha` es la columna de partición.
  - 5 claves duplicadas dentro de la tanda, con `updated_at` distinto: sin deduplicar, el MERGE debe fallar.
  - El último día nuevo llega con `estado = PENDIENTE`; el resto, `LIQUIDADA`. Las correcciones, `DEVUELTA`.
  - `data/` está cubierto por la regla `labs/**/data/` del `.gitignore` y se regenera con la semilla.
    ⚠️ Ojo: esta carpeta **todavía no es un repositorio git**, así que esa regla no protege nada por ahora.
- **Bucket de aterrizaje creado:** `gs://sdag-lab-000000-landing`, `US-CENTRAL1`, clase STANDARD y acceso
  uniforme a nivel de bucket. `sdag-pipeline` tiene `roles/storage.objectViewer` **solo sobre el bucket**; en la
  política del proyecto no se le añadió nada. El resto de bindings del bucket son los heredados por defecto
  (`legacyBucketOwner`/`legacyObjectOwner` para projectOwner y projectEditor).
  Sintaxis usada, documentada: `gcloud storage buckets create --location --default-storage-class
  --uniform-bucket-level-access` y `gcloud storage buckets add-iam-policy-binding`
  ([crear buckets](https://docs.cloud.google.com/storage/docs/creating-buckets), act. 2026-09-09 ·
  [add-iam-policy-binding](https://docs.cloud.google.com/sdk/gcloud/reference/storage/buckets/add-iam-policy-binding)).
  Nivel gratuito: 5 GB-mes y 5.000 operaciones de clase A, **agregado entre us-west1, us-central1 y us-east1**
  ([precios de Storage](https://cloud.google.com/storage/pricing)).

**Laboratorio del paso 3, ejecutado el 2026-09-12** (todo impersonando `sdag-pipeline`):

| Criterio | Resultado | Evidencia |
|---|---|---|
| 1 · bucket y rol | Bucket `us-central1`, acceso uniforme; SA con `objectViewer` **solo en el bucket** | `get-iam-policy` del bucket |
| 2 · columnas nuevas | `estado` y `updated_at` NULLABLE; las 1.957.639 filas previas con NULL | `con_estado = 0` antes del MERGE |
| 3 · tres fases | 5 objetos en GCS (7.011.558 B) → staging (57.347 filas) → MERGE | job `sdag_p3_load_tanda1` |
| 4 · **idempotencia** | 2.ª ejecución: **0 filas afectadas**; filas, ids y huella **idénticos** | `evidencia_despues_r1.json` = `_r2.json`, huella `289587634311190219` |
| 5 · correcciones | 40 de 40 con `DEVUELTA` y `updated_at`; **0 con el importe pisado a cero** | consulta por los 40 ids del manifiesto |
| 6 · duplicados | Las 5 claves repetidas quedan en **una fila cada una**, con el `updated_at` ganador; sin el error de "at most one source row" | consulta por los 5 ids |
| 7 · quién ejecuta | Todo con `CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT` | avisos de impersonación en cada job |
| 8 · evidencia | `evidencia_antes.json`, `_despues_r1.json`, `_despues_r2.json` + job ids | `labs/paso-3/` |

Antes: 1.957.639 filas. Después: **2.014.941** (+57.302 nuevas, 40 actualizadas). El MERGE declaró
`insertedRowCount: 57302` y `updatedRowCount: 40` = 57.342, que es exactamente la staging **deduplicada**
(57.347 filas, 57.342 ids).

**✅ Duda resuelta (la que el deep dive 05 dejó abierta):** un filtro sobre la columna de partición **dentro del
`ON` del MERGE sí satisface `require_partition_filter`**. El MERGE se ejecutó sin el error de eliminación de
particiones. Observado, **no documentado**: ninguna página lo afirma.

**✅ Verificación independiente del paso 3** (`verificacion/3-2026-09-12.md`): **PASA a la primera**, sin hallazgos
de gravedad media ni alta. Lo que hizo el verificador, que va más allá de leer mis ficheros:
- Reprodujo las seis cifras de cada fichero de evidencia **reconstruyendo el estado con *time travel*** antes de
  r1 y entre r1 y r2, después de recuperar la fórmula de la huella del texto de mis propios jobs.
- Comprobó que el manifiesto no está amañado: regeneración determinista idéntica y **md5 de GCS = md5 local** en
  los 5 ficheros.
- Verificó las 40 correcciones y los 5 duplicados **id a id**, y que el `importe` no quedó pisado (mínimo
  |importe| = 4,97; ninguno a 0).
- Confirmó que todos los jobs de BigQuery los ejecutó la cuenta de servicio. Matiz informativo: la subida a GCS
  la hizo el Owner, porque la SA solo tiene lectura — que es justo lo que pide el criterio 1.

**Hallazgos del paso 3 (para la lección):**
- **Las particiones procesadas cambian entre ejecuciones:** 2 en la primera y 5 en la segunda. En la primera solo
  existían las 2 particiones antiguas que se actualizan; las 3 nuevas nacían con el INSERT, así que no había nada
  que escanear. *(inferencia)*
- **Las dos ejecuciones facturaron 20.971.520 bytes** = 10 MiB × **2 tablas referenciadas** (destino y staging).
  El mínimo de 10 MiB es *"per table referenced by the query"*, no solo por consulta.
- **Repetir la carga con el mismo `--job_id` falla con `Already Exists: Job …`**, que es la idempotencia
  documentada de `jobs.insert`: *"You can retry as many times as you like on the same job ID, and at most one of
  those operations will succeed."* Protege de cargar dos veces, pero **no relanza** trabajo: para reprocesar a
  propósito hace falta un id nuevo.
- **El MERGE que actualiza paga `q' + t'`**, donde `t'` es el tamaño completo de las particiones tocadas antes de
  modificarlas. Por eso el filtro de partición en el `ON` es una decisión de dinero, no de estilo.

**Diagrama del paso 3:** `diagramas/paso-3.html` (tipo *dataflow*, 5 etapas: Origen → Aterrizaje → Staging →
MERGE → Tabla final), desde `paso-3.dataflow.json`. Validación showcase 9/9, 0 errores, 0 avisos; sin desbordes a
1440×900, 1600×1000, 1920×1080 ni 2048×1320. Dos arreglos, los dos señalados por el validador: ruta recta en
`GCS → Staging` (sus nodos no quedaban exactamente a la misma altura y salía un escalón de 7px, por debajo del
mínimo de 8) y `labelDy` en su etiqueta, que chocaba con el trazo del flujo de la cuenta de servicio.
Aprendido del paso 2 y aplicado aquí desde el principio: etiquetas cortas, tres filas y ningún control manual de
ruta hasta que un diagnóstico lo pida. Dos intentos en lugar de seis.
Capturas revisadas a mano en claro y oscuro: la cadena medida se sigue de un vistazo. ⚠️ Detalle sin corregir: el
trazo de `sdag-pipeline → Staging` sube por la columna de Aterrizaje y cruza la flecha de `bq load`, así que puede
leerse como si alimentara esa flecha en vez de ejecutar la carga. Se deja: pasa las comprobaciones de separación y
es la única arista que dice **quién** ejecuta.

**Lección 3** (`0003-cargar-dos-veces-y-que-no-pase-nada.md`):
1.ª verificación (`verificacion/3-leccion-2026-09-12.md`): **PASA CON RESERVAS**. Las 24 citas son literales y en
contexto, las 12 URL dan 200 sin redirección y el verificador reprodujo todas las cifras con `bq show -j`.
Corregido:
- **Media:** la receta de `--schema_update_option=ALLOW_FIELD_ADDITION` **no aplica a este pipeline**. Las
  opciones de esquema solo valen con `WRITE_APPEND`, `WRITE_TRUNCATE_DATA` o `WRITE_TRUNCATE` sobre una
  partición; la staging se carga con `--replace` sobre una tabla sin particionar, donde *"WRITE_TRUNCATE will
  always overwrite the schema"*. Reescrito para decir eso y para qué patrón sí sirve la opción.
- La cita de los load jobs fallidos estaba cortada a mitad de frase y pertenece a otra entrada de Quotas que la
  del 1.500. Completada, y añadido que ese techo **no acota los MERGE** (el DML está excluido) y que en tabla
  particionada por columna el límite son 30.000 modificaciones de partición al día.
- Señalado el salto MB→MiB en el mínimo facturado.
- El patrón `TIMESTAMP_ADD` para la expiración solo figura en un ejemplo de `CREATE VIEW`: dicho así.
- Añadidos los dos enlaces que faltaban: colocación us-central1 ↔ multirregión US, y la definición de
  `require_partition_filter` en términos de `WHERE` y predicado.
2.ª verificación (`verificacion/3-leccion-v2-2026-09-12.md`): **PASA**. Se le añadió un criterio que no estaba en
las rondas anteriores: **que las recetas que propone la lección sean aplicables al pipeline que describe** (es
justo lo que falló con `ALLOW_FIELD_ADDITION`). Resultado: 28 citas verbatim y en su página, 14 URL sin
redirección, 12 fechas correctas y 14 números reproducidos con `bq show -j`. Sus cuatro hallazgos bajos, también
aplicados: el matiz de las 30.000 modificaciones de partición donde solo se citaba el techo de 1.500; enlace a la
Storage Write API, cuya URL antigua redirige a la de gRPC; dos fuentes que faltaban en la lista; y el ⚠️ del
filtro en el `ON` matizado como *deducible pero no afirmado*, en vez de simplemente "no documentado".
**Paso 3 cerrado por completo el 2026-09-12.**

**Cambio en el diseño (2026-09-12): el paso 5 ahora incluye Beam y Dataflow.** Releído `docs/diseno.md`. Primero
Beam en local con DirectRunner (no toca GCP, no cuesta) y después **una sola ejecución** de la plantilla de
Dataflow con el mínimo de datos. Criterio nuevo: el trabajo termina en estado correcto y su coste queda bajo el
tope. **Guarda que me toca cumplir:** consultar los precios de Dataflow y de Sensitive Data Protection por encima
del primer GiB y contárselo al autor **antes** de lanzar el trabajo. El paso 3 no cambia.

### E · Paso 4 del laboratorio (en preparación, 2026-09-12)

**Decisiones del autor (2026-09-12), antes de construir:**
- **Airflow 2.11.1 en Docker local**, la misma versión que la imagen por defecto del Airflow gestionado
  (`composer-3-airflow-2.11.1-build.19`, marcada *"Default build"* el 2026-09-02).
- **Comparación sobre dos tablas de prueba vacías**, no sobre la tabla real de 2 M de filas.
- **Credenciales: ADC creadas con impersonación** de `sdag-pipeline`, montadas en el contenedor en solo lectura.

**Criterio de aceptación del paso 4, fijado antes de construir:**

1. Airflow **2.11.1** arranca con el compose oficial y el DAG se parsea sin errores.
2. El DAG hace, por intervalo diario: subir el fichero del día a GCS → cargar a una **staging por intervalo** →
   **MERGE** a la tabla destino → comprobación de calidad. Usa `data_interval_start`, **nunca** `now()`.
3. La autenticación es por **ADC con impersonación**. No hay claves de cuenta de servicio en disco ni en el repo.
4. **Criterio del diseño:** tres ejecuciones diarias (2026-09-02, 03 y 04) sobre `banca.p4_diario` y un **backfill**
   de esos mismos tres días sobre `banca.p4_backfill` dejan **el mismo número de filas y la misma huella de
   contenido**.
5. Relanzar cualquiera de los dos caminos no cambia el resultado.
6. Evidencia: huellas de las dos tablas, ids de los jobs de BigQuery y la salida del backfill.

**Criterio enmendado, aprobado por el autor el 2026-09-14** (opción "Enmendar los 3"). Los puntos 4, 5 y 6 no
cambian. Cambian estos tres, cada uno por un motivo comprobado:

1. Airflow **2.11.1** (imagen `apache/airflow:2.11.1`) arranca en Docker y el DAG se parsea sin errores.
   *Antes: "con el compose oficial".* **Motivo:** el servidor da 2 GiB al contenedor. Con `standalone` la primera
   tarea murió por falta de memoria (`oom_killed=true`), y el compose oficial pide *"At least 4GB of memory"*.
   Se usa un contenedor con `db migrate` y el scheduler (`labs/paso-4/remoto/docker-compose.yaml`).
2. El DAG hace, por intervalo diario: **esperar** el fichero del día en GCS → cargar a una **staging por día** →
   **validar** → **MERGE** a la tabla destino → comprobación de calidad. Todo se deriva de la **fecha lógica
   (`ds`)**, **nunca** de `now()`.
   *Antes: "subir el fichero" y "`data_interval_start`".* **Motivos:**
   - El fichero lo deja en GCS quien lo produce, y el orquestador espera a que exista. Es el patrón habitual, y
     los tres ficheros ya estaban subidos.
   - Una ejecución manual recibe el intervalo que **termina** en su fecha. Con `data_interval_start`, la del día
     3 cargó el fichero del día 2.
3. La autenticación es por **ADC con impersonación**. No hay claves de cuenta de servicio en disco ni en el repo.
   *Sin cambios.*

**Construido el 2026-09-12, sin arrancar todavía:**
- `labs/paso-4/docker-compose.yaml`: el **oficial de Apache para 2.11.1**, descargado sin tocar
  (`https://airflow.apache.org/docs/apache-airflow/2.11.1/docker-compose.yaml`, 11.342 bytes). Usa CeleryExecutor
  y ya incluye el servicio `airflow-triggerer`.
- `docker-compose.override.yaml`: monta el fichero de ADC en solo lectura y fija `GOOGLE_APPLICATION_CREDENTIALS`,
  el proyecto y el provider `apache-airflow-providers-google==22.4.0`.
  ⚠️ Sin confirmar si la imagen ya trae el provider; se fija la versión por si acaso.
- `dags/sdag_ingesta_diaria.py`: esperar fichero → staging del intervalo → validar → MERGE → comprobar. Todo
  derivado de `data_interval_start`. Con `force_rerun=False` y `job_id` determinista, y con esquema explícito
  porque `GCSToBigQueryOperator` trae `autodetect=True` y `write_disposition='WRITE_EMPTY'` por defecto.
- Tablas `banca.p4_diario` y `banca.p4_backfill`: vacías, mismo particionado y clustering que la real, con
  expiración a 7 días.
- Tres días nuevos (2026-09-02 a 09-04, **70.817 filas**, sin correcciones ni duplicados) generados y subidos a
  `gs://sdag-lab-000000-landing/p4/transacciones/dt=…` (8,26 MB en 3 objetos).
- `README.md` con la secuencia exacta y el porqué de cada decisión del DAG.
- **Comprobación estática del DAG** (sin Airflow, que no está instalado fuera del contenedor): sintaxis correcta,
  8 referencias a `data_interval_start`, `force_rerun=False`, `job_id` determinista, `WRITE_TRUNCATE` en la
  staging, `autodetect=False` y las cinco tareas encadenadas.
  Nota de método: mi primer comprobador dio que el DAG usaba `now()`. Era **falso positivo del propio
  comprobador**: la única aparición está en el docstring, citando el aviso de Airflow. Comprobado con grep antes
  de darlo por bueno.

**Dos bloqueos, los dos del autor (comprobado el 2026-09-12):**
1. **El demonio de Docker no está en marcha.** La CLI está instalada (Docker 24.0.2, Compose v2.18.1) pero
   `docker info` falla: *"this error may indicate that the docker daemon is not running"*. Hay que abrir Docker
   Desktop. Es una aplicación de escritorio: no la puede arrancar el agente.
2. **No existe el fichero de ADC.** Falta ejecutar
   `gcloud auth application-default login --impersonate-service-account=sdag-pipeline@…`, que abre el navegador.

**Diagnóstico de Docker (2026-09-12, tras abrir Docker Desktop):**
- Los procesos de Docker Desktop están en marcha (`Docker Desktop.exe`, `com.docker.backend.exe`).
- El contexto activo es `default` → `npipe:////./pipe/docker_engine`, pero Docker Desktop escucha en
  `npipe:////./pipe/dockerDesktopLinuxEngine` (contexto `desktop-linux`). **Los comandos tienen que ir con
  `--context desktop-linux`.** No se ha cambiado el contexto global: es configuración de la máquina del autor.
- Aun con ese contexto, `docker version` no responde en 25 s (exit 124 de `timeout`): el motor todavía no está
  listo o se ha quedado atascado al arrancar.

**2026-09-14:** el motor de Docker ya responde con `--context desktop-linux` (servidor 24.0.2). Imágenes de
Airflow descargándose.
**ADC creadas por el autor y verificadas** sin mostrar el contenido: el fichero existe en
`%APPDATA%\gcloud\application_default_credentials.json` y es de tipo `impersonated_service_account`, apuntando a
`sdag-pipeline@sdag-lab-000000.iam.gserviceaccount.com`.
**Nuevo problema:** Docker en local "deja frito el ordenador" del autor. Se estudia llevar Airflow a un VPS.

**Requisitos del compose oficial**, sacados del propio `docker-compose.yaml` (líneas 209-226, comprobación de
`airflow-init`): *"At least 4GB of memory required"*, *"At least 2 CPUs recommended"* y *"At least 10 GBs
recommended"* de disco. Son 7 servicios: Postgres, Redis, webserver, scheduler, worker, triggerer e init.

**VPS revisadas (2026-09-14, sondeo solo de lectura):**
- `vps-a` (VPS de 2 vCPU y 4 GB): **SSH rechazado** (`Permission denied
  (publickey)`). El alias de `~/.ssh/config` usa otro usuario, y su documentación dice `svc`
  con la clave `vps_a`. No se probaron otras combinaciones. Aunque entrara, 4 GB está en el mínimo y ahí
  corre un asistente con Telegram: poner credenciales de GCP junto a un agente expuesto a *prompt injection* es
  un riesgo.
- `vps-b` (4 CPU, 7,6 GB, 36 GB libres, Docker 29.3.1 y Compose v5.1.1): **solo 2,6 GB disponibles**, por
  debajo de los 4 GB que pide el compose, y ya aloja proyectos de terceros. Usarla implicaría copiar allí el
  fichero de ADC.
- El tercer alias de `~/.ssh/config` **no se tocó**: es ajeno al laboratorio.

**Conclusión:** ninguna VPS encaja tal cual con el compose completo. Decidir con el autor.

**Opción ligera confirmada en la documentación de Airflow 2.11.1:** *"The airflow standalone command initializes
the database, creates a user, and starts all components"*, con SQLite y `SequentialExecutor`, *"which will only
run task instances sequentially"*. Apache avisa de que no es para producción. Para este laboratorio basta: el DAG
ya lleva `max_active_runs=1` y el criterio no necesita paralelismo
([start](https://airflow.apache.org/docs/apache-airflow/2.11.1/start.html)).

**Actualización (2026-09-14):** el autor quiere Airflow en Docker **en una de sus máquinas**, pero **no en
`vps-b`**. Preparado `labs/paso-4/remoto/docker-compose.yaml`: un solo contenedor con `airflow standalone`,
interfaz solo en `127.0.0.1` (acceso por túnel SSH), credenciales en solo lectura y límite de 2 GB. Sirve para
cualquier máquina.
`vps-a` sigue rechazando SSH también con la conexión documentada en su documentación (usuario `svc`,
clave `vps_a`, un puerto no estándar): `Permission denied (publickey)`. No se probaron más combinaciones.
La descarga local de imágenes del compose completo terminó bien (exit 0): queda como alternativa.

**✅ Decidido por el autor (2026-09-14): Airflow corre en `vps-a`**, con el contenedor ligero de
`labs/paso-4/remoto/`. El autor arregla el acceso SSH. Antes de copiar credenciales hay que comprobar la RAM libre
(la máquina tiene 4 GB y ya corre otro servicio propio). Riesgo aceptado a sabiendas: el fichero de ADC queda en un servidor
que también aloja un asistente con acceso por Telegram. Mitigación: carpeta propia con permisos 600, montaje en
solo lectura y borrado al acabar el paso.

**Preparado para `vps-a` (2026-09-14), sin ejecutar:**
- `labs/paso-4/remoto/desplegar.sh`: no despliega si hay menos de 1,5 GB de RAM disponible; crea
  `~/sdag-airflow` con la carpeta de credenciales en 700; copia compose, DAG y ADC (este en 600); arranca con el
  UID del usuario remoto.
- `labs/paso-4/remoto/limpiar.sh`: para el contenedor, borra las credenciales con `shred` y **comprueba** que el
  fichero ya no existe.
- **Por qué el agente no entra en `vps-a` aunque el autor sí (diagnóstico local del 2026-09-14, sin nuevos
  intentos de conexión):** el servidor solo acepta clave pública, y la clave `~/.ssh/vps_a` **tiene frase
  de paso**. El autor la teclea; el agente corre sin terminal interactiva y no puede. El agente SSH de Windows
  estaba parado y deshabilitado, sin claves. El Git Bash tampoco tiene agente.
  Solución propuesta: que el autor cargue la clave **una vez** en el agente de Windows (tecleando él la frase de
  paso) y el agente use el `ssh.exe`/`scp.exe` de Windows, que sí ve ese agente. La frase de paso no pasa nunca
  por el chat. Los dos scripts ya aceptan `SSH=` y `SCP=` y convierten las rutas locales con `cygpath -w`.
- **✅ Acceso resuelto (2026-09-14):** el autor cargó la clave en el agente SSH de Windows (lo hizo con
  PowerShell). `ssh-add -l` la muestra como `llave-vps-a (ED25519)`, y el `ssh.exe` de Windows ya entra en
  `vps-a` sin interacción.
  Tropiezo: pasar el comando remoto como argumento desde PowerShell 5.1 rompe el entrecomillado (quita las
  comillas internas y el bash remoto falla con `syntax error near unexpected token`). Se resuelve mandando el
  script por la entrada estándar (`ssh.exe vps-a 'bash -s' <<'EOF' … EOF`) desde Git Bash.
- **Sondeo de `vps-a` (2026-09-14, solo lectura):** host `vps-a-01`, usuario `lab` (uid 1001, grupos `lab
  sudo users`), 2 CPU, 3,8 GB de RAM con **2,7 GB disponibles**, Docker 29.2.0 y Compose v5.0.2.
  **Dos bloqueos:**
  1. **Disco: 38 GB con 33 GB usados, solo 3,4 GB libres (91 %).** El compose oficial recomienda al menos
     10 GB. Legible sin `sudo`: `/var/log` 1,5 GB y `/home` 526 MB; el resto (probablemente las imágenes de
     Docker de otro servicio propio) no se puede medir sin `sudo`. Llenar el disco tumbaría otro servicio propio.
  2. **Docker sin permisos:** `docker ps` da *"permission denied while trying to connect to the docker API"*.
     El grupo `docker` solo tenía al usuario de servicio, y `sudo -n` confirma que `sudo` **pide contraseña**, que el agente
     no puede teclear ni debe recibir por el chat. Añadir `lab` al grupo `docker` equivale a darle acceso de root.
  Además, el Docker Desktop local volvió a estar cerrado: no se pudo medir la imagen en local.
  Tamaño de `apache/airflow:2.11.1` según la API pública de Docker Hub: **0,64 GB comprimida** (linux/amd64;
  etiqueta actualizada el 2026-02-28). ⚠️ Descomprimida ocupa más: no medido.
  `desplegar.sh` ahora **para** si hay menos de 3 GB de disco libre o si el usuario remoto no puede usar Docker.
- **✅ Bloqueos resueltos por el autor (2026-09-14):** `sudo journalctl --vacuum-size=200M` (`/var/log` bajó de
  1,5 GB a 421 MB; disco libre de 3,4 a **4,5 GB**, 88 % usado) y `sudo usermod -aG docker lab` (el grupo `docker`
  ahora tiene `svc,lab`, y `docker ps` funciona sin `sudo`). ⚠️ Deshacer al cerrar el paso:
  `sudo gpasswd -d lab docker`.
  En el servidor corren contenedores de otro servicio propio desde hace meses: no se tocan.
  ⚠️ El servidor tiene un **reinicio pendiente** (31 paquetes). No se reinicia: pararía otro servicio propio. Decisión de
  El autor.
- **Despliegue lanzado** con `desplegar.sh` usando el `ssh.exe`/`scp.exe` de Windows.
- **⚠️ Incidente (2026-09-14): el despliegue casi llena el disco de `vps-a`.** En un minuto el disco pasó de
  4.484 MB libres a **1.068 MB (98 %)**, con otro servicio propio corriendo en la misma máquina. Se paró todo en cuanto se
  vio: `docker compose down`, credenciales borradas con `shred` y comprobadas, e imagen eliminada. Resultado:
  **4.484 MB libres (88 %), igual que antes**, y los contenedores de otro servicio propio siguieron en marcha sin cortes.
  **Qué ocupó cada cosa**, medido por lo que liberó cada paso:
  - Contenedor (capa escribible: pip del provider de Google y sus dependencias, más la base SQLite): **547 MB**.
  - Imagen `apache/airflow:2.11.1`: **2.869 MB en disco**. `docker image inspect --format '{{.Size}}'` decía
    0,64 GB, el tamaño comprimido: **no sirve para planificar disco**.
  **Causa:** error de estimación del agente. El freno de `desplegar.sh` exigía 3 GB libres y el despliegue real
  necesitaba unos 3,4 GB más margen.
  **Hallazgo de paso:** la imagen **ya trae** `apache-airflow-providers-google` **19.5.0**. Pip lo sustituyó por
  la 22.4.0 junto con dependencias pesadas (`google-cloud-aiplatform`, `litellm`, `opentelemetry-*`). Cierra el ⚠️
  de si la imagen traía el provider.
  **El DAG sí se cargó:** `airflow dags list` mostraba `sdag_ingesta_diaria`. `list-import-errors` falló solo
  porque `standalone` aún no había inicializado la base.
- **Decisión del autor (2026-09-14): redesplegar en `vps-a` liberando disco.** `desplegar.sh` ahora exige
  **7 GB libres** (el doble de lo medido).
- **Redespliegue sin pip:** el provider **19.5.0** de la imagen tiene todos los parámetros del DAG. Comprobado
  leyendo con `ast` las firmas `__init__` reales de la wheel de PyPI, sin ejecutar nada:
  `BigQueryInsertJobOperator`, `BigQueryCheckOperator`, `GCSToBigQueryOperator` y `GCSObjectExistenceSensor`.
  Antes, dos intentos de extraer las firmas del HTML de la documentación fallaron por mis expresiones regulares;
  se dejó de adivinar el formato. Quitado `_PIP_ADDITIONAL_REQUIREMENTS` del compose remoto.
- **Desglose del disco de `vps-a`** (solo lectura, como `lab`): 38 GB en total, 33,6 usados, 4,48 libres.
  **Docker no es lo que lo llena:** `docker system df` da 17 imágenes con 1,298 GB (las mayores,
  `agentscope-workspace:*`, de 419 MB cada una, comparten capas), 6 contenedores en marcha con 38 MB, sin
  volúmenes, sin imágenes colgadas y sin contenedores parados. El journal ocupa 8 MB y `/var/cache/apt` 110 MB.
  **Unos 30 GB están en rutas que `lab` no puede leer.** ⚠️ La columna RECLAIMABLE salió negativa
  (`-4.302e+08B`): con el almacén de containerd, `docker system df` no es fiable para esto. Para decidir qué
  borrar hace falta que el autor liste con `sudo` los directorios grandes.
- **Listado con `sudo` del autor (2026-09-14):** de los 32 GB usados bajo `/`, **26 GB están en
  `/home/svc`**, el home del usuario de ese otro servicio. El resto es pequeño: `/var` 2,0 GB (`/var/lib`
  1,5 GB, `/var/log` 421 MB, `/var/cache` 121 MB), `/usr` 1,5 GB, `/home/lab` 526 MB y `/boot` 116 MB. Como
  `/var/lib` entero ocupa 1,5 GB, Docker y containerd no pasan de ahí.
  **Conclusión:** liberar los ~2,5 GB que faltan implica borrar dentro del home del bot. El agente no elige qué
  borrar ahí a ciegas: hace falta ver sus subcarpetas y que el autor decida.
  ⚠️ Riesgo estructural: con 26 GB del bot en un disco de 38 GB, aunque se liberen 2,5 GB el laboratorio
  correría con el disco en torno al 80-85 %.
- **✅ Cambio de decisión del autor (2026-09-14): se despliega en `vps-b`** (36 GB libres), no en `vps-a`.
  En `vps-a` no queda nada del laboratorio salvo `~/sdag-airflow` con el compose y el DAG, sin credenciales.
  ⚠️ Pendiente de deshacer en `vps-a`: `sudo gpasswd -d lab docker`.
  En `vps-b` se entra como `root`: `desplegar.sh` ahora usa el UID 50000 para el contenedor y le da la
  propiedad del fichero de credenciales, que sigue en 600.
  Corregido antes de ejecutar: la primera versión del caso `root` hacía `chmod 755 ~` y `chmod 711` sobre las
  carpetas del host, lo que habría abierto permisos del home de root. No hacía falta (el montaje lo resuelve el
  demonio de Docker, que corre como root) y se quitó.
- **Sondeo de `vps-b` antes de desplegar (2026-09-14):** `root` (uid 0), 2.603 MB de RAM disponibles,
  36.790 MB de disco libre (50 %), puerto 8080 libre y sin `~/sdag-airflow` previo.
- **Despliegue lanzado en `vps-b`**, sin pip, con el ssh/scp de Git Bash (esa máquina usa una clave sin
  frase de paso).
- **✅ Airflow sano en `vps-b` (2026-09-14):**
  - Contenedor en marcha; base lista a los ~5 s.
  - `airflow dags list-import-errors` → `No data found`: **el DAG carga sin errores**.
  - `sdag_ingesta_diaria` listado, en pausa por defecto.
  - Proceso con UID **50000**; credenciales en `-rw------- airflow root`.
  - **Autenticación de punta a punta:** dentro del contenedor, `google.auth.default()` carga las credenciales y
    `bigquery.Client().list_datasets()` devuelve `['banca']`.
  - Flags de backfill en 2.11.1: `-c, --conf`, `-s, --start-date` y `-e, --end-date`.
  - Disco tras arrancar: 33.744 MB libres (55 %), unos 3 GB usados, como se midió en `vps-a`.
  - ⚠️ Memoria al arrancar: **1,578 de 2 GiB**, con la CPU al 108 %. Vigilar si el límite provoca un OOM
    durante las ejecuciones.
  - `pip show` no devolvió versión del provider dentro del contenedor; da igual, porque no se instaló nada y el
    DAG importa bien.
- **Ajuste del DAG antes de ejecutar:** `end_date=datetime(2026, 9, 4)`. Sin él, al despausar, el scheduler
  (`@daily`, `catchup=False`) crearía por su cuenta una ejecución del intervalo más reciente, que esperaría un
  fichero inexistente y ensuciaría la evidencia del criterio.
- **Tropiezo al activar el DAG (2026-09-14):** el script esperaba ver `end_date` en `airflow dags details`, pero
  en 2.11.1 esa salida **no incluye `start_date` ni `end_date`** (sí `is_paused`, `schedule_interval` y
  `max_active_runs`). El bucle agotó los intentos y `timeout` cortó la conexión. Como la condición nunca se
  cumplió, **no se despausó nada**. Comprobado después: DAG en pausa, **ninguna ejecución** (`No data found`), y el
  contenedor sano (0 reinicios, sin OOM, 1,707 de 2 GiB en reposo, cada llamada a la CLI tarda unos 3 s).
  Se pasa a comprobar el `end_date` con Python dentro del contenedor, sobre el DAG del fichero y sobre la copia
  serializada que usa el scheduler.
  ⚠️ Memoria en reposo al 85 % del límite. Si hay un OOM durante las ejecuciones, la mitigación prevista es
  `AIRFLOW__WEBSERVER__WORKERS=1`.
- **Segundo tropiezo, también mío:** la primera comprobación con Python no devolvió nada porque lancé
  `docker exec` **sin `-i`**: el script de la entrada estándar no llegó a Python. Con `docker exec -i` funciona.
- **Ejecuciones diarias en curso (2026-09-14, lectura en vivo a las ~08:50 UTC):**
  - `manual__2026-09-02` en **running** desde las 08:44:19; su primera tarea (`esperar_fichero`) no arrancó hasta
    las 08:48:40, **más de 4 minutos después**. Las otras cuatro, sin empezar.
  - `manual__2026-09-03` en **queued**, esperando por `max_active_runs=1`.
  - ~~La ejecución del 2026-09-04 no aparece~~ **Corregido a las 08:50 UTC:** `manual__2026-09-04T00:00:00+00:00`
    **sí existe** (en queued). Cuando miré, el bucle aún no la había creado. La hipótesis de que
    `end_date=2026-09-04` impedía el disparo manual queda **refutada**. Sigue abierto si el **backfill** con
    `--end-date 2026-09-04` incluye ese intervalo: se verá al lanzarlo.
    La documentación de 2.11.1 no lo resuelve: solo dice que `end_date` es *"A date beyond which your DAG won't
    run, leave to None for open-ended scheduling"*, sin aclarar qué pasa con el intervalo que empieza justo en
    esa fecha ([DAG API](https://airflow.apache.org/docs/apache-airflow/2.11.1/_api/airflow/models/dag/index.html)).
  - Contenedor sano: 0 reinicios, sin OOM, 1,648 de 2 GiB, CPU 59 %.
  - **Mi estimación de 5-10 minutos era mala:** con `SequentialExecutor` en un contenedor justo de memoria, cada
    tarea arranca un proceso de Python nuevo. Nueva estimación: 30-45 minutos para las tres ejecuciones.
- **❌ Las ejecuciones se atascaron por falta de memoria (diagnóstico a las 09:06 UTC):**
  - La orden en segundo plano agotó su espera (`timeout`, exit 124) sin ver terminar ninguna ejecución.
  - Contenedor: **2 GiB de 2 GiB, `oom_killed=true`**, CPU al 304 %, 0 reinicios del contenedor.
  - La primera tarea, `esperar_fichero` del día 2, iba por el **segundo intento**. Su log:
    *"Job 5 was killed before it finished (likely due to running out of memory)"*, con señal 9 al grupo del
    proceso. El día 2 seguía en running y los días 3 y 4 en queued. **No se cargó ningún dato.**
  - Una comprobación intermedia no imprimió nada porque mandé a `/dev/null` los errores del Python del contenedor.
    Se rehízo con una sola llamada a la CLI, cronometrada y con los errores visibles, y leyendo los logs del disco.
  - **Causa, del agente:** `airflow standalone` mete webserver (varios procesos gunicorn), scheduler, triggerer y
    cada tarea en el mismo límite de 2 GiB. En reposo ya estaba al 85 %; se anotó el riesgo y se siguió.
  - **Arreglo:** el contenedor arranca solo `airflow db migrate && airflow scheduler`, sin webserver ni triggerer,
    y sin publicar el 8080. Se mantienen los 2 GiB para no quitar memoria a lo que ya corre en la máquina. El
    triggerer no hace falta porque el sensor usa `mode="reschedule"`. Al recrear el contenedor se descarta la
    base SQLite con las ejecuciones atascadas.
  - **✅ Redespliegue solo con scheduler (2026-09-14):**
    - Antes de tocar nada, BigQuery seguía limpio: `p4_diario` y `p4_backfill` con **0 filas** y ninguna tabla
      `stg_p4_*`.
    - Compose validado en el servidor por la entrada estándar (`docker compose -f - config`) y después recreado
      el contenedor.
    - Base nueva lista a los ~5 s. **Memoria: 111 MiB de 2 GiB** (antes 1,6-2,0 GiB), sin OOM.
    - DAG serializado en la base nueva con `end_date 2026-09-04`, en pausa y sin errores de importación.
    - El `exit=1` de aquella orden era la última línea del propio script (`grep -q` sin coincidencias), no un
      fallo.
- **❌ Error de diseño del DAG, confirmado con pruebas (2026-09-14): las ejecuciones manuales procesan el día
  anterior.**
  - En Airflow 2.11.1, `dags trigger -e 2026-09-02` creó una ejecución con **fecha lógica 2026-09-02** e
    **intervalo 2026-09-01 → 2026-09-02**. Las del 3 y del 4, igual: el intervalo **termina** en la fecha lógica.
  - El DAG construía rutas, staging y fechas del MERGE con `data_interval_start`, así que el sensor de la ejecución
    del día 2 esperaba **literalmente** `gs://…/p4/transacciones/dt=2026-09-01/parte-000.csv` (campo renderizado
    leído de la base de Airflow).
  - Un backfill usa el intervalo que **empieza** en cada fecha. Los dos caminos del criterio habrían procesado
    días distintos y la comparación no habría medido la idempotencia.
  - **Forense en BigQuery** (`INFORMATION_SCHEMA.JOBS`):
    - A las **09:08:58 UTC** el contenedor anterior, antes de recrearlo, cargó con el job
      `airflow_sdag_ingesta_diaria_cargar_staging_2026_09_03T…` en **`stg_p4_20260902`**: la ejecución del día 3
      procesó el fichero del día 2.
    - A las **09:09:17 UTC**, MERGE `sdag_p4_p4_diario_20260902_372a…` en `p4_diario`: **19.796 insertadas, 0
      actualizadas**.
    - `p4_diario` quedó con **solo el 2026-09-02 y 19.796 filas**, igual que el manifiesto para ese día. El dato es
      correcto, pero lo escribió la ejecución equivocada.
    - Poco antes le dije al autor "0 filas": era cierto al comprobarlo y dejó de serlo antes de recrear el
      contenedor.
  - **Hallazgo lateral:** con `force_rerun=False`, el operador añade al `job_id` un sufijo con el hash de la
    configuración (`_372a…`). Es determinista (misma configuración, mismo id), pero no es literalmente el texto
    que se le pasa.
  - **Arreglo:** el DAG usa la **fecha lógica** (`{{ ds }}`, `{{ ds_nodash }}`) en lugar de `data_interval_start`.
    Con horario cron, en las ejecuciones programadas y en el backfill la fecha lógica coincide con el inicio del
    intervalo; en las manuales es la fecha de `-e`. Los dos caminos procesan el mismo día.
  - **✅ Reset aprobado por el autor y hecho (2026-09-14):** `01_tablas_prueba.sql` recreó `p4_diario` y
    `p4_backfill` (*Replaced*), `DROP TABLE stg_p4_20260902`. Comprobado: **0 filas en las dos y ninguna
    `stg_p4_*`**.
  - **✅ Redespliegue limpio del DAG corregido:** DAG copiado y contenedor recreado con `--force-recreate` (el
    compose no cambiaba, y sin ese flag se habría quedado la base con las ejecuciones mal fechadas). Base lista a los
    ~5 s, scheduler vivo, DAG visible, **en pausa y sin ejecuciones**, 459 MiB y sin OOM.
  - Tropiezo: la prueba de `airflow tasks render` salió "NO RENDERIZADO" por mi filtro. El valor aparece dos
    líneas debajo de `# property: object` y yo miraba solo la siguiente. Se repite mostrando la salida en bruto
    antes de despausar.
  - **✅ Arreglo demostrado antes de ejecutar nada** (`airflow tasks render`, sin ejecutar tareas): con fecha
    lógica 2026-09-02 el sensor espera `p4/transacciones/dt=2026-09-02/parte-000.csv`; con 09-03, `dt=2026-09-03`;
    con 09-04, `dt=2026-09-04`. Cada ejecución procesa su propio día.
- **Tres ejecuciones diarias lanzadas de nuevo (2026-09-14, 09:29:43 UTC):**
  - Scheduler vivo, DAG despausado y **0 ejecuciones creadas por su cuenta** antes de lanzar.
  - `dags trigger -e` para el 2, el 3 y el 4, con destino `p4_diario`.
  - Los intervalos siguen siendo los de un disparo manual (el día anterior a la fecha lógica), pero el DAG ya no
    depende de ellos: el sensor de `manual__2026-09-02`, en una **ejecución real**, espera
    `p4/transacciones/dt=2026-09-02/parte-000.csv` (campo renderizado leído de la base de Airflow).
  - El día 2 en running y los días 3 y 4 en queued. Contenedor con 468 MiB, 0 reinicios y sin OOM.
- **❌ Las tres fallaron en `esperar_fichero` (09:30-09:38 UTC):** 3 intentos por ejecución, ~143 s cada una,
  memoria estable en ~470 MiB y sin OOM. Log del intento 1 y del 3:
  *"AirflowNotFoundException: The conn_id `google_cloud_default` isn't defined"*, lanzada desde `GCSHook.__init__`
  al leer los extras de la conexión. El sensor ya buscaba el fichero correcto (*"Sensor checks existence of :
  sdag-lab-000000-landing, p4/transacciones/dt=2026-09-02/parte-000.csv"*).
  **Causa, introducida por el agente al arreglar el OOM:** `airflow standalone` crea las conexiones por defecto;
  `airflow db migrate && airflow scheduler` no. Por eso el primer contenedor sí cargó datos y este no. La prueba de
  credenciales anterior pasó porque llamaba a `google.auth.default()` directamente, sin pasar por la conexión de
  Airflow: **probaba otra cosa**.
  **Evidencia intacta:** `p4_diario` y `p4_backfill` con 0 filas, ninguna `stg_p4_*`, y los tres objetos
  `p4/transacciones/dt=2026-09-0{2,3,4}/parte-000.csv` en GCS.
  **Arreglo:** `AIRFLOW_CONN_GOOGLE_CLOUD_DEFAULT: "google-cloud-platform://"` en el compose remoto, una
  conexión vacía que usa ADC y no lleva secretos. Documentado: *"Application Default Credentials can be used for a
  connection by specifying an empty URI"*
  ([conexión de Google Cloud](https://airflow.apache.org/docs/apache-airflow-providers-google/stable/connections/gcp.html)).
  Ojo al comprobarlo: las conexiones por variable de entorno *"will not show up in the Airflow UI or using airflow
  connections list"* ([Managing connections, 2.11.1](https://airflow.apache.org/docs/apache-airflow/2.11.1/howto/connection.html)).
  Se prueba con el **hook** (`GCSHook().exists`, `BigQueryHook`), que es la capa que usa el DAG, no con
  `google.auth` ni con `connections list`.
- **✅ Arreglo de la conexión probado y ejecuciones relanzadas (2026-09-14):**
  - Compose validado en el servidor con `AIRFLOW_CONN_GOOGLE_CLOUD_DEFAULT: google-cloud-platform://`.
  - Contenedor recreado con base limpia: base lista a los ~5 s, scheduler vivo y DAG visible.
  - **Prueba en la capa del DAG, a través de `google_cloud_default`:** `GCSHook().exists('sdag-lab-000000-landing',
    'p4/transacciones/dt=2026-09-02/parte-000.csv')` → **`True`**, y `BigQueryHook(...).get_client().list_datasets()`
    → **`['banca']`**.
  - Despausado a las **09:42:29 UTC**, con 0 ejecuciones creadas por su cuenta.
  - Lanzadas `manual__2026-09-02/03/04`: la del día 2 en running y las otras en queued. 468 MiB, sin OOM.
- **Resultado de las tres ejecuciones diarias (09:44-09:48 UTC):**
  - ✅ **Días 3 y 4: completas**, las cinco tareas, en 47 y 45 s. En `p4_diario`, **23.201** y **27.820** filas con ids
    únicos, **iguales al manifiesto**. MERGE `sdag_p4_p4_diario_20260903_6d72…` (09:46:31) y
    `…20260904_aab4…` (09:47:17), solo inserciones.
  - ❌ **Día 2: falla en `merge_al_destino`** tras 3 intentos: *"Job … `sdag_p4_p4_diario_20260902_372a…` already
    exists and is in DONE state. If you want to force rerun it consider setting `force_rerun=True`. Or, if you want
    to reattach in this scenario add DONE to `reattach_states`"*. Sensor, carga y validación fueron bien:
    `stg_p4_20260902` existe.
  - **Causa: el job id determinista funcionando tal cual.** La ejecución mal fechada de las 09:09:17 ya había lanzado
    un MERGE con **la misma configuración**, así que mismo id y mismo hash. Ese job sigue en el historial de BigQuery
    (6 meses). Después se vació `p4_diario`, así que **sus 19.796 filas ya no están**.
  - **Por qué no sirve lo que sugiere el error:** con `DONE` en `reattach_states`, la tarea se reengancharía al job
    viejo y quedaría como correcta **sin ejecutar el MERGE**, y el día 2 faltaría en la tabla. Con `force_rerun=True`
    el id llevaría un sufijo aleatorio y se perdería el determinismo que se quiere demostrar.
  - **Arreglo:** prefijo del `job_id` `sdag_p4r2_` en lugar de `sdag_p4_`. Sigue siendo determinista y esquiva el id
    ocupado. Se relanza **solo** `merge_al_destino` y lo posterior del día 2 (`tasks clear`), sin recrear el
    contenedor, para conservar el historial de las ejecuciones del 3 y el 4.
  - **Para la lección:** es el caso de la lección 3 visto en directo. Un id fijo impide pagar dos veces, pero un
    reproceso intencionado necesita un id nuevo.
- **✅ Camino diario completo (2026-09-14, 09:51:33 UTC):**
  - DAG con el prefijo nuevo copiado; el DAG serializado lo recogió en ~10 s
    (`sdag_p4r2_{{ params.destino }}_{{ ds_nodash }}`).
  - `tasks clear -s 2026-09-02 -e 2026-09-02 -t '^merge_al_destino$' -d -y`, con los flags comprobados en su ayuda.
  - `manual__2026-09-02` pasó a **success**: `merge_al_destino:success(x4)`, que son los 3 intentos fallidos más el
    relanzado, y `comprobar_destino:success`.
  - **`p4_diario`: 2026-09-02 = 19.796, 09-03 = 23.201, 09-04 = 27.820 filas, ids únicos, idénticas al manifiesto.**
  - Siguiente: backfill del 2 al 4 contra `p4_backfill`, lanzado desacoplado dentro del contenedor
    (`docker exec -d`) porque en 2.x el backfill corre dentro del proceso de la CLI. Antes se comprueba
    `core.dag_run_conf_overrides_params`: si no estuviera activo, el `--conf` no cambiaría el destino.
- **❌ El primer backfill no ejecutó nada (09:52:33 UTC), comprobado con pruebas:**
  - `core.dag_run_conf_overrides_params = True`. El log dice *"finished run 3 of 3 | succeeded: 15 | failed: 0"*
    y *"Backfill done"* **en 7 segundos**.
  - **`p4_backfill`: 0 filas**, y ningún MERGE `sdag_p4r2_p4_backfill_*` en `INFORMATION_SCHEMA.JOBS`.
  - En la base de Airflow, las tres ejecuciones `manual__2026-09-0{2,3,4}` quedaron con **`run_type=backfill`** y
    **`conf={'destino': 'p4_backfill'}`**, y con inicio y fin de la ejecución reiniciados a las 09:52:39. Sus
    tareas conservan las horas del camino diario (09:43-09:51).
  - Log: *"Marking run <DagRun … manual__2026-09-04 …> … DagRun Finished"*, igual para las tres.
  - **Causa:** en Airflow 2.11.1, `dags backfill` sobre fechas lógicas que **ya tienen ejecución** reutiliza esas
    ejecuciones. Como todas sus tareas estaban en `success`, no había nada que ejecutar: las marcó terminadas y les
    cambió tipo y conf.
  - **Consecuencia:** el registro de Airflow de las ejecuciones diarias ya no es fiable. La evidencia buena del
    camino diario está en BigQuery: `p4_diario` igual al manifiesto y los MERGE hacia `p4_diario`.
  - **Hallazgo lateral:** `sdag_p4r2_p4_diario_20260902_372a…` lleva **el mismo hash** que el id que chocó
    (`sdag_p4_…_372a…`). El sufijo es el hash de la configuración del job; solo cambió el prefijo.
  - **Evidencia guardada antes de tocar Airflow:** `labs/paso-4/evidencia_airflow_diario.json` (ejecuciones y
    tareas, con los campos alterados señalados) y `labs/paso-4/evidencia_bigquery_jobs.json` (cargas y MERGE de
    hoy sobre `p4_*` y `stg_p4_*`).
  - **Plan:** recrear el contenedor para que no haya ejecuciones en esas fechas, dejar el DAG **en pausa**
    (`dags backfill` no necesita el scheduler) y repetir el backfill, que tendrá que crear `backfill__…` y
    ejecutar las tareas. `pgrep` da *Permission denied* en el contenedor: el fin se detectará por la línea
    *"Backfill done"* del log y por el estado de las ejecuciones.
- **✅ Backfill repetido en limpio (2026-09-14, 09:58-10:02 UTC):**
  - Contenedor recreado a las 09:58:23 con `--force-recreate`. Antes de lanzar nada: 0 ejecuciones, DAG en pausa,
    `dag_run_conf_overrides_params=True`, `GCSHook().exists` = True y `BigQueryHook` → `['banca']`.
  - Backfill lanzado a las 09:58:52 y terminado a las 10:01:43: *"Backfill done"*, `EXIT=0`. Creó
    `backfill__2026-09-0{2,3,4}`, con `conf={'destino': 'p4_backfill'}` e intervalo que empieza en su fecha. Las
    15 tareas corrieron de verdad (horas 09:59:04-10:01:38), un día detrás de otro. Memoria máxima ~1 GiB, sin OOM.
  - MERGE en `INFORMATION_SCHEMA.JOBS`: `sdag_p4r2_p4_backfill_20260902_e8c9…` (19.796 insertadas),
    `…20260903_4f57…` (23.201) y `…20260904_3240…` (27.820). 0 actualizadas; 21 MB facturados cada uno.
  - **Comparación** (`sql/02_comparar.sql`, las tres consultas):
    - [1] `p4_diario` y `p4_backfill`: 70.817 filas, 70.817 ids únicos, huella `792921986835855836` en las dos.
    - [2] `filas_solo_en_diario = 0` y `filas_solo_en_backfill = 0`.
    - [3] Por día: 19.796 / 23.201 / 27.820 en las dos tablas, igual que `manifiesto_incremental.json`.
  - Evidencia: `labs/paso-4/evidencia_airflow_backfill.json`, `evidencia_bigquery_jobs.json` (17 jobs, reexportado
    con el backfill) y `evidencia_comparacion.json`.
  - **Lección para la 0004:** un backfill no es "otra forma de ejecutar". En Airflow 2 comparte la clave de fecha
    lógica con las ejecuciones existentes. Si esas fechas ya se ejecutaron, las reutiliza y **no ejecuta nada**,
    aunque el log diga "succeeded: 15". Para comparar dos caminos hacen falta dos historiales separados, y la
    prueba es BigQuery, no el log.
- **❌ Criterio 5 (relanzar), primer intento, 10:10-10:15 UTC: la tabla no cambia, pero la ejecución falla.**
  - `airflow dags backfill -s 2026-09-03 -e 2026-09-03 --reset-dagruns -y -c '{"destino": "p4_backfill"}'`.
  - `p4_backfill` antes y después: 70.817 filas, 70.817 ids y huella `792921986835855836`. Sin cambios.
  - Pero `merge_al_destino` falló en los tres intentos (el último, el 4) con *"Job with id:
    sdag_p4r2_p4_backfill_20260903_4f57… already exists and is in DONE state"*. `comprobar_destino` quedó en
    `upstream_failed`, la ejecución en `failed` y el backfill con `EXIT=1`.
  - **Causa:** con `force_rerun=False`, el id es `prefijo + hash de la configuración`. Relanzar el mismo día genera
    el mismo id, y ese id ya está ocupado por un job terminado.
  - **La salida que propone el propio error tampoco sirve.** El código de `BigQueryInsertJobOperator.execute` en el
    provider 19.5.0, leído dentro del contenedor, hace:
    `if job.state == "DONE": raise AirflowException("Job is already in state DONE. Can not reattach to this job.")`.
  - **Corrección del DAG:** `job_id="sdag_p4r3_{{ params.destino }}_{{ ds_nodash }}_t{{ ti.try_number }}"` con
    `force_rerun=True`, sin `reattach_states`. La idempotencia la pone el MERGE, que ya se probó en el paso 3.
    Lo que se pierde es el reenganche a un MERGE que siga RUNNING; con el MERGE idempotente y
    `max_active_runs=1`, el riesgo es aceptable.
  - **Qué no cambia:** el MERGE, la staging, el sensor y la validación son idénticos. La comparación del criterio 4
    se hizo con la versión anterior, que solo difiere en cómo se nombra el job.
  - **Pendiente:** repetir la prueba de relanzar con el DAG corregido, en los dos caminos.
- **✅ Criterio 5 con el DAG corregido, relanzando un día (10:18-10:22 UTC):**
  - DAG subido y sin errores de importación: `job_id` con `ti.try_number`, `force_rerun=True`,
    `reattach_states=set()`.
  - **Backfill:** `dags backfill -s 2026-09-03 -e 2026-09-03 --reset-dagruns` terminó con *"Backfill done"* y
    `EXIT=0`. MERGE `sdag_p4r3_p4_backfill_20260903_t5_8758…`: 0 insertadas, 0 actualizadas, 0 borradas.
  - **Diario:** ejecución manual con fecha lógica `2026-09-03T12:00:00+00:00`, con `ds=2026-09-03` y `conf={}`, es
    decir, destino `p4_diario`. Terminó en `success`. MERGE `sdag_p4r3_p4_diario_20260903_t1_32e7…`: 0/0/0.
  - **Por qué a las 12:00:** en Airflow 2 la clave única de una ejecución es `dag_id` + fecha lógica, y la de las
    00:00 ya la tenía `backfill__2026-09-03`. El DAG solo usa `ds`, así que procesa el mismo día.
  - Huellas antes y después: las dos tablas con 70.817 filas y `792921986835855836`. Sin cambios.
  - Los dos jobs los ejecutó `sdag-pipeline@…`, con 20.971.520 bytes facturados cada uno.
- **✅ Criterio 5 completo: relanzados los tres días en los dos caminos (10:25-10:57 UTC).**
  - **Backfill** `-s 2026-09-02 -e 2026-09-04 --reset-dagruns -y`: *"Backfill done"*, `EXIT=0`. MERGE
    `sdag_p4r3_p4_backfill_20260902_t2_…`, `…20260903_t6_…` y `…20260904_t2_…`, los tres con 0/0/0.
  - **Diario:** ejecuciones manuales a las 12:00 de los días 2 y 3 (la del 3 volvió a correr, intento 2, porque
    `--reset-dagruns` limpia todas las ejecuciones del rango). MERGE `sdag_p4r3_p4_diario_20260902_t1_…` y
    `…20260903_t2_…`, con 0/0/0.
  - **❌→✅ Trampa del 2026-09-04:** `manual__2026-09-04T12:00` terminó en `success` con **0 tareas**. Su fecha
    lógica era posterior al `end_date` (2026-09-04 00:00), y Airflow no crea instancias de tareas fuera de su
    rango. Es otro "success" que no ejecuta nada. **Arreglo:** `end_date=datetime(2026, 9, 4, 23, 59, 59)`, que no
    cambia las ejecuciones programadas ni las de backfill. Se relanzó como `manual__2026-09-04T12:30`: 5/5 tareas
    y MERGE `sdag_p4r3_p4_diario_20260904_t1_5ccd…` con 0/0/0.
  - **Huellas** antes (10:24:51 y 10:54:10) y después (10:30:22 y 10:56:25): las dos tablas con 70.817 filas,
    70.817 ids y `792921986835855836`.
  - Los 34 jobs de BigQuery del día sobre `p4_*` y `stg_p4_*` los ejecutó `sdag-pipeline@…`.
  - **Evidencia:**
    - `labs/paso-4/evidencia_airflow_relanzar.json`: 7 ejecuciones con sus tareas.
    - `evidencia_bigquery_jobs.json`: 34 jobs.
    - `evidencia_logs/`: `arranque_y_parseo.txt` y los cuatro logs de backfill. Revisados: sin tokens ni claves.
  - `evidencia_logs/arranque_y_parseo.txt`: imagen `apache/airflow:2.11.1`, `airflow version` 2.11.1,
    `list-import-errors`: *"No data found"*, `DagBag import_errors`: ninguno. Contenedor sin OOM y con 0 reinicios.
- **✅ Servidor limpio (10:57 UTC):** `HOST=vps-b SSH=ssh bash labs/paso-4/remoto/limpiar.sh`.
  Contenedor y red borrados; `gcp/` vacía (credenciales con `shred`). Quedan el compose y el DAG. 33.906 MB libres.
- `labs/paso-4/README.md` reescrito con lo que se ejecutó de verdad: servidor, un contenedor, recrear antes del
  backfill, `force_rerun=True` y `end_date`.
- **En curso:** verificador independiente con el criterio enmendado → `verificacion/4-2026-09-14.md`.
  Borrador de la lección en `0004-el-backfill-que-no-hizo-nada.md`, con
  5 ⚠️. Después, diagrama.
- **Diagrama preparado mientras verifica:** `diagramas/paso-4.html`, de tipo dataflow, generado desde `paso-4.dataflow.json`.
  - `validate --quality showcase`: 9/9 comprobaciones, 0 errores y 0 avisos, tras dos arreglos
    (`route: straight` y `labelDy: -26` en `merge → p4_diario`).
  - `deliver`: exit 0, HTML de 719.199 bytes, sha256 `d3425d0a…`.
  - `visual-check`: sin desbordamiento a 1440, 1600 y 1920. La revisión visual la hago yo con las capturas.
  - **Revisión visual hecha** sobre `1440x900.light.png` y `2048x1320.dark.png`:
    - Camino principal legible, sin cruces ni etiquetas tapadas, y las dos salidas del MERGE diferenciadas.
    - La leyenda y los controles del visor salen en inglés (*primary data*, *data flow*), como en los pasos 2 y 3.
      Es la interfaz fija del renderizador: con contenido en español no se fija `meta.locale`.
- **✅ `end_date` confirmado antes de despausar (2026-09-14):** en el fichero (`start_date 2026-09-02`,
  `end_date 2026-09-04`, `catchup False`, cron `0 0 * * *`, sin errores de importación) y en la **copia
  serializada** que usa el scheduler (`end_date 2026-09-04`, actualizada a las 08:36:35 UTC).
- En el compose remoto se añadió `user: "${AIRFLOW_UID:-50000}:0"`, el mismo patrón del compose oficial. Sin eso,
  el proceso correría con el UID 50000 y no podría leer un fichero de credenciales en 600 del usuario remoto.

**Histórico de la decisión:** Opciones planteadas: un solo contenedor con
`airflow standalone` en local (recomendada), la VPS `vps-b` o una VPS nueva y temporal. El autor respondió
con una captura del lanzador de **sesiones en la nube de Claude** (entorno "Default", repositorio GudAgents,
rama main). Pendiente de confirmar que se refiere a eso. Se está investigando si esas sesiones admiten Docker,
servicios persistentes y credenciales. Condicionantes ya conocidos: esta carpeta **no es un repositorio git**, el
repositorio de la captura es otro proyecto, y habría que llevar allí el fichero de ADC.

**Qué dice la documentación de Claude Code sobre las sesiones en la nube** (consultado el 2026-09-14,
[cloud environments](https://code.claude.com/docs/en/cloud-environments.md) ·
[Claude Code on the web](https://code.claude.com/docs/en/claude-code-on-the-web.md)):
- Docker, `docker compose` y `dockerd` vienen **preinstalados**.
- Recursos: **4 vCPU, 16 GB de RAM y 30 GB de disco**. Sobra para el compose completo, que pide 4 GB.
- Red: el nivel por defecto permite `*.googleapis.com` y Docker Hub.
- No hace falta GitHub: se pueden enviar repositorios locales sin remoto. ⚠️ Pero tiene que ser un repositorio
  git, y esta carpeta no lo es.
- **Los procesos no sobreviven entre sesiones**: la caché guarda ficheros, no procesos, y los servicios hay que
  arrancarlos en cada sesión.
- Credenciales: variables de entorno visibles para quien use el entorno, o el almacén de credenciales de API
  (planes Pro/Max).
- ⚠️ No documentado en lo consultado: si el puerto 8080 de Airflow es accesible desde el navegador, y cuánto
  tarda en expirar una sesión inactiva.

**Lectura propia, distinta del veredicto del subagente** ("no es viable"): el laboratorio no necesita Airflow
encendido días, sino unos 30 minutos dentro de **una sola sesión** (arrancar, tres ejecuciones, backfill,
comparar). Dentro de una sesión los procesos sí corren. Es viable para una ejecución puntual, con dos costes:
llevar el fichero de ADC a un entorno de terceros, y no poder ver la interfaz de Airflow si el puerto no se expone.

**⚠️ Aviso de facturación (2026-09-14).** Google envió al autor *"Acción necesaria: tu cuenta de facturación
XXXXXX-XXXXXX-XXXXXX tiene cargos pendientes o sus datos de pago no son válidos"*, avisando de que podría
suspender o cancelar la cuenta y los proyectos. Comprobado en ese momento con gcloud: la cuenta sigue
`open: True` y `sdag-lab-000000` con `billingEnabled: True`, así que **aún no hay suspensión**. **El autor lo
arregló en la consola el 2026-09-14.** No se sabe qué proyecto generó el cargo: el laboratorio va dentro del nivel
gratuito, pero la cuenta paga otros 3 proyectos.

Hasta que estén los dos, el laboratorio del paso 4 no puede avanzar: arrancar los contenedores, lanzar las tres
ejecuciones diarias, el backfill y la comparación dependen de ambos.
Si Docker acabara siendo un problema, la alternativa sería instalar Airflow 2.11.1 en un entorno virtual, pero eso
se aleja del diseño (`docs/diseno.md`: "Airflow en Docker local") y habría que decidirlo con el autor.

**Guarda de coste, del informe de documentación:** **no se crea ningún entorno gestionado**. Se factura la
capacidad provisionada mientras el entorno existe, ejecute DAGs o no: *"costs are charged for the environment's
DCU value over time, DCU-hours"* y *"billed … for the actual time period when it was running"*
([precios](https://cloud.google.com/products/managed-service-for-apache-airflow/pricing)).
⚠️ Sin confirmar: cuántos DCU consume cada tamaño de entorno, así que no se puede dar un € al mes de un entorno
ocioso. El Airflow del laboratorio va en Docker.

## Estado por paso

| Paso | Laboratorio | Verificación | Lección | Diagrama |
|---|---|---|---|---|
| 0 | Proyecto creado · configuración `sdag-lab` creada **sin activar** | — | — | — |
| 1 | ✅ Proyecto `sdag-lab-000000` · presupuesto 1 € · cuenta de servicio `sdag-pipeline` | ✅ PASA (`1-2026-09-11.md`) | ✅ `0001-el-presupuesto-no-es-un-freno.md` (PASA a la 3.ª, `1-leccion-v3-2026-09-11.md`) | ✅ `diagramas/paso-1.html` |
| 2 | ✅ Dataset `banca` (US) · tabla particionada y clusterizada · 1,96 M filas | ✅ PASA (`2-2026-09-12.md`) | ✅ `0002-lo-que-de-verdad-lee-una-consulta.md` (PASA a la 4.ª) | ✅ `diagramas/paso-2.html` |
| 3 | ✅ GCS → staging → MERGE · 2.014.941 filas | ✅ PASA (`3-2026-09-12.md`) | ✅ `0003-cargar-dos-veces-y-que-no-pase-nada.md` (PASA a la 2.ª) | ✅ `diagramas/paso-3.html` |
| 4 | ✅ Airflow 2.11.1 · diario = backfill: 70.817 filas, huella `792921986835855836` · relanzar = 0 filas | ⏳ verificador en curso (`4-2026-09-14.md`) | ⏳ borrador `0004-el-backfill-que-no-hizo-nada.md` | ✅ `diagramas/paso-4.html` |
| 5 | | | | |
| 6 | | | | |
| 7 | | | | |
| 8 | | | | |

