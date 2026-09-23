# sensitive-data-agent-gcp

A data engineering lab on Google Cloud, built step by step on **synthetic banking data**.

The goal is to learn GCP data engineering by building it, not by reading about it: a pipeline that goes
from raw files to an agent over sensitive data, where every step has to survive an independent check
before it counts as done.

**It is half finished: 4 of the 8 steps are built.** What follows says exactly which ones, and what the
gaps are.

---

## What makes it different: a falsifiable acceptance criterion per step

Every step is written down with an **acceptance criterion that can fail** *before* anything is built.
When the step is finished, a **separate agent that did not build it** is given only that criterion and
the artefact — no conversation, no reasoning, no notes from whoever built it — and has to run the checks
itself and write a verdict: **PASS · PASS WITH RESERVATIONS · FAIL**. Its report goes in
[`verificacion/`](verificacion/). A step is not done until it has a report.

A concrete example — the criterion for step 3 is that **running the same load twice must not duplicate
rows**. Not "the MERGE looks correct": the verifier re-ran the load, counted rows, compared content
fingerprints in both directions and checked key uniqueness. See
[`verificacion/3-2026-09-12.md`](verificacion/3-2026-09-12.md).

This is also why the verdicts are not all green. Step 4 came back **PASS WITH RESERVATIONS**, because
part of the evidence (the Airflow version, the DAG parsing cleanly) only existed in exported files by the
time the verifier looked, and the server was already shut down. That reservation is in the report,
unedited.

The protocol itself is in [`verificacion/README.md`](verificacion/README.md).

---

## The 8 steps

| # | Step | Status |
|---|------|--------|
| 1 | GCP from an AWS background: hierarchy, IAM, service accounts, budgets | ✅ Built · verified **PASS** |
| 2 | BigQuery internals: storage vs compute, partitioning, clustering | ✅ Built · verified **PASS** |
| 3 | Incremental ingestion: GCS → staging → MERGE, late data, schema evolution | ✅ Built · verified **PASS** |
| 4 | Airflow and its managed service: DAGs, retries, backfills | ✅ Built · verified **PASS WITH RESERVATIONS** |
| 5 | PII tokenization with Sensitive Data Protection + Beam/Dataflow | ⬜ Designed, not built |
| 6 | Governance and data quality: policy tags, column-level security, masking | ⬜ Not started |
| 7 | From data to LLM: embeddings and vector search in BigQuery | ⬜ Not started |
| 8 | Agent over sensitive data: fail-closed guard, audited re-identification | ⬜ Not started |

The full plan, with the acceptance criterion for each of the eight, is in
[`docs/diseno.md`](docs/diseno.md). The running log — decisions, dead ends, what broke and why — is in
[`docs/progreso.md`](docs/progreso.md).

---

## What is actually covered

- **BigQuery partitioning and clustering.** A `transacciones` table partitioned by day, clustered by
  `cuenta_id, tipo`, with `require_partition_filter = TRUE`. Pruning is measured against the **real job
  statistics** (`totalBytesProcessed`, `totalPartitionsProcessed`), not a dry run: one day reads under
  5% of the bytes of the full 90-day range, and a query with no partition filter fails instead of
  scanning the table. ~1.96M rows. → [`labs/paso-2/`](labs/paso-2/)
- **Idempotent incremental loading with staging + MERGE.** Immutable files in
  `gs://…/transacciones/dt=YYYY-MM-DD/` → per-day staging table → `MERGE` on `transaccion_id` into the
  final table. Handles late corrections and duplicate keys in the same batch. Running it twice changes
  nothing. ~2.01M rows. → [`labs/paso-3/`](labs/paso-3/)
- **Airflow with backfills.** Airflow 2.11.1 in Docker (the same image version the managed Google service
  defaults to), orchestrating steps 2–3. Everything derives from the logical date `ds`, never `now()`.
  Three daily runs and a three-day backfill produce the same row count and the same content fingerprint;
  re-running either path writes 0 rows. → [`labs/paso-4/`](labs/paso-4/)
- **Least-privilege access.** A dedicated service account with `bigquery.jobUser` at project level and
  `dataEditor` scoped to the one dataset; **no service account keys on disk or in the repo** —
  authentication is ADC with impersonation. A budget alert exists before any other resource.
  → [`verificacion/1-2026-09-11.md`](verificacion/1-2026-09-11.md)
- **PII tokenization** is the subject of step 5 and is designed in detail (deterministic tokenization,
  KMS-wrapped keys, the cost of joining across tokenized tables), but **it has not been built or run**.

## What is not covered yet

- **Governance and data quality** (step 6): policy tags, column-level security, masking, quarantine.
- **Embeddings and vector search** (step 7).
- **The agent over sensitive data** (step 8): the fail-closed guard, audited re-identification, leak
  testing. Despite the repo name, this does not exist yet.
- **Beam and Dataflow** (step 5): planned as a local DirectRunner pipeline plus a single run of the
  Dataflow tokenization template. Neither has been run.

---

## Limitations, unvarnished

- **Synthetic data only.** Generated by the scripts in `labs/paso-*/generar_*.py` from a fixed seed.
  No real PII has ever touched this project, by rule.
- **The generated CSVs are not in the repo** (they are large and reproducible). Re-run the generator
  scripts to recreate them; the manifests describe what they should contain.
- **Airflow is self-hosted, not managed.** It ran in Docker on a small personal VPS, in a single
  container with no webserver and no published ports, precisely to avoid paying for a managed
  environment — which bills for existing, not for running DAGs. So nothing here demonstrates Cloud
  Composer / Managed Service for Apache Airflow in practice.
- **Step 4's evidence is partly exported files.** See the reservation above.
- **Nothing is deployed and running.** The lab resources live in a throwaway personal GCP project with
  a 1 EUR budget alert; the Airflow host was wiped after the step-4 run.
- **The docs are in Spanish.** The design, the log and the verification reports were written as working
  documents, not as a showcase, and they are kept as they were written — including the mistakes.
- **The long-form lesson notes live outside this repo.** What is here is the lab, the evidence and the
  verification reports.

---

## Layout

```
docs/          design and plan (diseno.md), running log (progreso.md)
labs/paso-N/   the lab for each step: SQL, generators, DAG, compose, evidence
verificacion/  independent verification reports, one per step (+ the protocol)
diagramas/     a standalone HTML diagram of the system state after each step
entorno.sh     loads the gcloud config for this lab into the current shell only
entorno.ps1    same, for PowerShell
```

## Running it

You need your own GCP project. Nothing here will work against someone else's.

1. Sign in with the account you want to use, **without** activating it globally:

   ```
   gcloud auth login YOUR_ACCOUNT --no-activate
   ```

2. Create a gcloud configuration named `sdag-lab` pointing at your project, then load it into each new
   terminal:

   ```
   source entorno.sh        # Bash
   . .\entorno.ps1          # PowerShell
   ```

   This sets `CLOUDSDK_ACTIVE_CONFIG_NAME` for that shell only, so it never touches your global active
   configuration.

3. Set a budget alert before creating anything else.

Project IDs, billing account IDs and account names have been replaced with placeholders
(`sdag-lab-000000`, `XXXXXX-XXXXXX-XXXXXX`, `you@example.com`) throughout the documents and the
evidence files. Substitute your own.

## Working rules

The rules this project was built under — no invented facts, official documentation with a consultation
date for every technical claim, whoever builds does not verify, one lesson and one diagram per step —
are in [`CLAUDE.md`](CLAUDE.md).
