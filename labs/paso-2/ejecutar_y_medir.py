"""Ejecuta las consultas del paso 2 y recoge las estadísticas reales de cada job.

Cada consulta se lanza con un job id propio y después se lee `bq show -j` para sacar
`totalPartitionsProcessed`, `totalBytesProcessed` y `totalBytesBilled`. Esa es la evidencia de que la poda
por partición funciona. Las consultas que deben fallar (sin filtro de partición) se registran con su error.

Por defecto ejecuta todo impersonando la cuenta de servicio del pipeline.

Uso:
    python ejecutar_y_medir.py sql/04_consultas_poda.sql --salida resultados_poda.json
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

PROYECTO = "sdag-lab-000000"
UBICACION = "US"
SA = "sdag-pipeline@sdag-lab-000000.iam.gserviceaccount.com"


def entorno(impersonar):
    env = dict(os.environ, CLOUDSDK_ACTIVE_CONFIG_NAME="sdag-lab")
    if impersonar:
        env["CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT"] = SA
    return env


def bq(args, env):
    # shell=True en Windows: bq es un .cmd y no se ejecuta directamente.
    cmd = "bq " + " ".join(args)
    p = subprocess.run(cmd, shell=True, capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
    return p.returncode, (p.stdout or ""), (p.stderr or "")


def trocear(sql_texto):
    """Devuelve [(etiqueta, sentencia)] a partir de los comentarios '-- [n] TITULO'."""
    bloques, etiqueta, acumulado = [], None, []
    for linea in sql_texto.splitlines():
        m = re.match(r"^--\s*\[(\d+)\]\s*(.+?)\.?\s*$", linea)
        if m:
            if etiqueta and "".join(acumulado).strip():
                bloques.append((etiqueta, "\n".join(acumulado).strip()))
            etiqueta, acumulado = f"{m.group(1)} · {m.group(2)}", []
        elif etiqueta is not None and not linea.lstrip().startswith("--"):
            acumulado.append(linea)
    if etiqueta and "".join(acumulado).strip():
        bloques.append((etiqueta, "\n".join(acumulado).strip()))
    return bloques


def medir(etiqueta, sentencia, indice, env, marca):
    job_id = f"sdag_p2_{marca}_{indice}"
    # En Windows el comando va a cmd.exe: el SQL tiene que ir en una sola línea.
    sql = " ".join(sentencia.split()).rstrip(";")
    # --nouse_cache: sin esto, repetir una consulta la sirve desde la caché y da 0 bytes procesados.
    code, out, err = bq([f"--location={UBICACION}", f"--project_id={PROYECTO}", "query",
                         "--use_legacy_sql=false", "--nouse_cache", f"--job_id={job_id}", "--format=none",
                         f'"{sql}"'], env)
    r = {"etiqueta": etiqueta, "job_id": job_id, "ok": code == 0}
    if code != 0:
        # bq escribe el aviso de impersonación en stderr y a veces el error en stdout: se miran los dos.
        lineas = [l.strip() for l in (err + "\n" + out).splitlines()
                  if l.strip() and not l.startswith("WARNING: This command is using")]
        r["error"] = " ".join(lineas)[:600]

    code2, out2, err2 = bq(["show", "--format=prettyjson", "-j", job_id], env)
    if code2 == 0:
        try:
            q = json.loads(out2).get("statistics", {}).get("query", {})
            r["particiones_procesadas"] = q.get("totalPartitionsProcessed")
            r["bytes_procesados"] = q.get("totalBytesProcessed")
            r["bytes_facturados"] = q.get("totalBytesBilled")
            r["precision_estimacion"] = q.get("totalBytesProcessedAccuracy")
            r["desde_cache"] = q.get("cacheHit")
        except json.JSONDecodeError:
            r["error_estadisticas"] = out2[:300]
    else:
        r["error_estadisticas"] = err2.strip()[:300]
    return r


def main():
    p = argparse.ArgumentParser()
    p.add_argument("fichero_sql", type=Path)
    p.add_argument("--salida", type=Path, default=Path(__file__).parent / "resultados_poda.json")
    p.add_argument("--sin-impersonar", action="store_true", help="Ejecuta con la cuenta de usuario activa")
    a = p.parse_args()

    env = entorno(not a.sin_impersonar)
    marca = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    resultados = []
    for i, (etiqueta, sentencia) in enumerate(trocear(a.fichero_sql.read_text(encoding="utf-8")), start=1):
        print(f"[{i}] {etiqueta} ...", flush=True)
        r = medir(etiqueta, sentencia, i, env, marca)
        resultados.append(r)
        estado = "OK" if r["ok"] else f"FALLA: {r.get('error', '')[:110]}"
        print(f"    {estado} · particiones={r.get('particiones_procesadas')} "
              f"bytes_procesados={r.get('bytes_procesados')} bytes_facturados={r.get('bytes_facturados')}")

    salida = {
        "generado": datetime.now(timezone.utc).isoformat(),
        "impersonando": None if a.sin_impersonar else SA,
        "proyecto": PROYECTO,
        "consultas": resultados,
    }
    a.salida.write_text(json.dumps(salida, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\n-> {a.salida}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
