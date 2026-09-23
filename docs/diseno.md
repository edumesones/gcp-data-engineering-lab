# Diseño — sensitive-data-agent-gcp

> Plan fijado el 2026-09-11. Plazo estimado: dos o tres semanas.

## Para qué existe

1. **Cerrar el hueco de GCP**: llegar a GCP desde AWS y desde un uso de BigQuery limitado a consultar.
2. **Aprender construyendo**: cada lección del temario tiene su laboratorio aquí.
3. **Dejar constancia falsable** de lo aprendido: cada paso tiene criterio de aceptación y un informe
   de verificación independiente. Es un proyecto propio de aprendizaje, no experiencia de producción.

## Qué se construye

Un pipeline sobre **datos bancarios sintéticos**, de la ingesta al agente:

```
datos sintéticos (clientes, cuentas, transacciones, notas de caso)
  → Cloud Storage
  → Airflow en Docker local                orquesta
  → Sensitive Data Protection              tokeniza en la ingesta, clave envuelta con Cloud KMS
  → BigQuery                               particionado, clustering, carga idempotente con MERGE
  → calidad de datos y acceso por columna
  → embeddings de notas ya tokenizadas → búsqueda vectorial en BigQuery
  → agente LangGraph para analistas        guardián fail-closed; reidentificación solo por
                                           herramienta autorizada y auditada
  → evaluación de fugas
```

**Por qué banca:** es el dominio donde la pregunta técnica se pone más fina. Cruzar clientes entre
tablas tokenizadas exige tokenización determinista, con un coste de seguridad que hay que saber
defender.

## Plan: 8 pasos, cada uno lección + laboratorio + diagrama + verificación

| Paso | Lección (vault) | Laboratorio | Criterio de aceptación |
|---|---|---|---|
| 1 | GCP viniendo de AWS: jerarquía, IAM, cuentas de servicio, presupuestos | Proyecto con alerta de presupuesto y cuenta de servicio de mínimo privilegio | Presupuesto con alerta activo; la cuenta de servicio solo tiene los roles listados |
| 2 | BigQuery por dentro: almacenamiento y cómputo, on-demand frente a capacidad, particionado, clustering | Datasets y tablas particionadas con datos sintéticos | Consultas con poda de partición verificada por bytes procesados |
| 3 | Ingesta a BigQuery: lotes frente a Storage Write API, staging y MERGE, datos tardíos, esquema | Carga incremental idempotente | Relanzar la misma carga dos veces no duplica filas |
| 4 | Airflow y su servicio gestionado: DAGs, reintentos, backfills | DAG local que orquesta pasos 2-3 | Un backfill de tres días produce el mismo resultado que tres ejecuciones diarias |
| 5 | Tokenización con Sensitive Data Protection: determinista, preservando formato, hash, KMS. **Beam y Dataflow**: modelo de programación, ventanas, watermarks y datos tardíos | Tokenizar PII en la ingesta, en dos tiempos: primero un pipeline **Beam en local con DirectRunner**, después **una sola ejecución de la plantilla de Dataflow de tokenización hacia BigQuery** con el mínimo de datos | Ningún campo sensible en claro en BigQuery; el JOIN por cliente tokenizado funciona; el trabajo de Dataflow termina en estado correcto y su coste queda por debajo del tope |
| 6 | Gobierno y calidad: policy tags, seguridad por columna, enmascaramiento, Knowledge Catalog | Controles de calidad y acceso | Un usuario sin rol ve el campo enmascarado; un registro inválido va a cuarentena |
| 7 | Del dato al LLM: embeddings y búsqueda vectorial en BigQuery | Notas tokenizadas a embeddings | La búsqueda devuelve metadatos sin consultas extra; ningún embedding de texto en claro |
| 8 | Agentes sobre datos sensibles y despliegue | Agente con guardián y reidentificación auditada | Batería de fugas: 0 datos sensibles en respuestas no autorizadas; cada reidentificación queda en el log |

### Dataflow y Beam en el paso 5 (añadido el 2026-09-12)

**Por qué entran.** Google documenta la tokenización hacia BigQuery **con una plantilla de Dataflow**,
así que es el camino que hay que recorrer para entender de verdad cómo se tokeniza en la ingesta.
Además, Dataflow es el hueco de GCP más caro de improvisar: el comando es fácil, pero lo que hay
debajo es Apache Beam.

**En dos tiempos, y en este orden:**

1. **Beam en local con DirectRunner.** No pasa por GCP y no cuesta nada. Aquí se aprende lo que de verdad
   preguntan: PCollections y transformaciones, ventanas, watermarks, triggers, datos tardíos y por qué el
   mismo pipeline sirve para lote y para streaming.
2. **Una única ejecución de la plantilla de Dataflow** con el conjunto de datos más pequeño que demuestre
   el flujo, para tocar Dataflow y Sensitive Data Protection de verdad.

**Guardas de coste, antes de lanzar nada en Dataflow:**

- ⚠️ **Sin comprobar:** el precio de Dataflow y el de Sensitive Data Protection por encima del primer GiB
  gratuito. Consultar las páginas oficiales de precios **antes** de la ejecución.
- El presupuesto de 1 € **solo avisa, no corta**, y tarda horas: no sirve de freno para un trabajo que
  arranca máquinas.
- Trabajo por lotes, no en streaming; el mínimo de trabajadores; y comprobar que el trabajo **termina**,
  porque un trabajo de streaming se queda encendido.
- Borrar los recursos al acabar y confirmar el gasto real al día siguiente.

**Qué permite decir después, y qué no.** Permite decir *"he ejecutado la plantilla de tokenización de
Sensitive Data Protection sobre Dataflow en un proyecto propio, y he escrito pipelines de Beam en
local"*. **No** permite decir "extensive GCP experience".

Los criterios de aceptación son lo que recibe el verificador independiente. Se pueden afinar al empezar
cada paso, **antes** de construir, nunca después de ver el resultado.

## Coste y seguridad

- Sin Composer. Airflow en local.
- Alerta de presupuesto antes que cualquier recurso.
- Recursos agrupados en un único proyecto GCP para poder borrarlos de golpe.
- Sin claves de cuenta de servicio en disco. ADC.
- Solo datos sintéticos.

## Fuera de alcance

- **Looker:** fuera. Modelar con LookML no cubre el hueco real, que es GCP de datos. Ojo con
  confundirlo con Looker Studio, que es otro producto.
- **Composer** (hoy *Managed Service for Apache Airflow*): se estudia en el paso 4, no se paga. El Airflow
  del laboratorio va en Docker local. ⚠️ **Sin comprobar:** un entorno de Composer está encendido aunque no
  ejecutes nada, así que hay que mirar su página de precios antes de crear uno, aunque sea temporal.
- **Dataflow:** ya **no** está fuera de alcance. Entra acotado al paso 5, con las guardas de coste de arriba.
