# sensitive-data-agent-gcp

Laboratorio de aprendizaje: pipeline de datos sensibles en GCP, de la ingesta al agente, sobre datos
bancarios sintéticos. Existe para **aprender ingeniería de datos en GCP construyéndola**, paso a paso,
con una lección escrita por cada paso.

> **Al empezar una sesión:** lee `docs/progreso.md`, sección **"Siguiente paso"**. Ahí está dónde se
> quedó el trabajo, qué está bloqueado y qué ya está decidido. No vuelvas a preguntar lo que ya consta.

---

## Las tres normas (no negociables)

### 1. No inventar

- Todo dato técnico de GCP (comportamiento de un servicio, límite, precio, estado GA/Preview, nombre)
  lleva **enlace a documentación oficial y fecha de consulta**. La memoria del modelo no es fuente.
- Si no se puede confirmar: `⚠️ Sin confirmar`, nunca se rellena con lo que "suele" ser cierto.
- Google **renombró varios servicios en 2026**. Comprobar el nombre vigente antes de escribirlo:
  Cloud Composer → Managed Service for Apache Airflow · Dataproc → Managed Service for Apache Spark ·
  Vertex AI → Gemini Enterprise Agent Platform · Dataplex → Knowledge Catalog ·
  Vector Search 2.0 → Agent Retrieval.

### 2. Tests y pruebas con un subagente aparte

**Quien construye no verifica.** Toda verificación la hace un **subagente nuevo** que recibe:

- el **criterio de aceptación** escrito del paso,
- el **artefacto** (código, tabla, DAG, lección),
- y nada más: **ni la conversación, ni el razonamiento, ni las notas** de quien lo construyó.

El verificador escribe su informe en `verificacion/{paso}-{fecha}.md` con veredicto
**PASA · PASA CON RESERVAS · NO PASA**. Un paso no se da por terminado sin ese informe en PASA.
Protocolo completo en `verificacion/README.md`.

### 3. Cada paso: lección + diagrama

Cada paso del laboratorio se cierra con tres cosas, en este orden:

1. **Verificación independiente** (norma 2)
2. **Lección escrita**, a nivel senior: no explicar qué es un embedding; sí explicar GCP, que es lo nuevo
3. **Diagrama** del estado del sistema tras ese paso, guardado en `diagramas/`

---

## GCP: cuenta y configuración

- Configuración de gcloud dedicada al laboratorio: **`sdag-lab`**.
- **Nunca** usar ni activar la configuración `default` de la máquina: puede apuntar a otro proyecto.
- Antes de cualquier comando de gcloud o bq, cargar el entorno del proyecto:
  - Bash: `source entorno.sh`
  - PowerShell: `. .\entorno.ps1`
  Fija `CLOUDSDK_ACTIVE_CONFIG_NAME=sdag-lab` solo para esa terminal y `CLOUDSDK_PYTHON` a Python 3.12.
- **Presupuesto con alerta antes que cualquier otro recurso.** Confirmar el tope antes de crearlo.
- **Sin Composer** (coste fijo): Airflow en Docker local.
- **Nunca claves de cuenta de servicio en disco ni en el repo.** Autenticación por ADC.
- **Solo datos sintéticos.** Nunca PII real.
- Antes de crear un recurso que cueste dinero, decirlo y confirmar.

## Contexto

Diseño y plan: `docs/diseno.md` · avance: `docs/progreso.md`
