"""Genera transacciones bancarias sintéticas para el paso 2.

Sin PII: cuenta_id es un identificador interno inventado (no un IBAN) y no hay nombres ni documentos.
Determinista: con la misma semilla y los mismos parámetros produce exactamente los mismos ficheros.

Uso:
    python generar_transacciones.py                  # 90 días desde 2026-06-01, ~2M filas
    python generar_transacciones.py --dias 3 --filas-dia 100 --salida data/prueba
"""

import argparse
import csv
import json
import random
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

TIPOS = [("TARJETA", 0.55), ("TRANSFERENCIA", 0.20), ("DOMICILIACION", 0.12), ("RETIRADA", 0.08), ("INGRESO", 0.05)]
CANALES = {
    "TARJETA": ["APP", "WEB", "TPV"],
    "TRANSFERENCIA": ["APP", "WEB", "OFICINA"],
    "DOMICILIACION": ["SISTEMA"],
    "RETIRADA": ["CAJERO", "OFICINA"],
    "INGRESO": ["CAJERO", "OFICINA", "APP"],
}
PAISES = [("ES", 0.86), ("PT", 0.03), ("FR", 0.03), ("DE", 0.02), ("GB", 0.02), ("US", 0.02), ("MX", 0.01), ("AE", 0.01)]
COLUMNAS = ["transaccion_id", "cuenta_id", "fecha", "ts_operacion", "importe", "divisa", "tipo", "canal", "pais_contraparte"]


def elegir(rng, opciones):
    valores, pesos = zip(*opciones)
    return rng.choices(valores, weights=pesos, k=1)[0]


def importe(rng, tipo):
    # Log-normal por tipo: muchas operaciones pequeñas y una cola de importes altos.
    mu, sigma = {"TARJETA": (3.0, 0.9), "TRANSFERENCIA": (5.5, 1.2), "DOMICILIACION": (4.2, 0.6),
                 "RETIRADA": (4.0, 0.7), "INGRESO": (6.0, 1.0)}[tipo]
    valor = round(min(rng.lognormvariate(mu, sigma), 250_000), 2)
    return valor if tipo == "INGRESO" else -valor


def generar(inicio, dias, filas_dia, n_cuentas, semilla, salida):
    rng = random.Random(semilla)
    salida.mkdir(parents=True, exist_ok=True)
    fichero = salida / "transacciones.csv"
    manifiesto = {"semilla": semilla, "inicio": inicio.isoformat(), "dias": dias, "filas_por_dia": {}, "total": 0}
    secuencia = 0

    with fichero.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(COLUMNAS)
        for d in range(dias):
            dia = inicio + timedelta(days=d)
            # Variación diaria de ±20 % y menos actividad en fin de semana.
            factor = rng.uniform(0.8, 1.2) * (0.7 if dia.weekday() >= 5 else 1.0)
            n = int(filas_dia * factor)
            for _ in range(n):
                secuencia += 1
                tipo = elegir(rng, TIPOS)
                ts = datetime(dia.year, dia.month, dia.day, tzinfo=timezone.utc) + timedelta(seconds=rng.randrange(86_400))
                w.writerow([
                    f"TX{secuencia:010d}",
                    f"CU{rng.randrange(1, n_cuentas + 1):07d}",
                    dia.isoformat(),
                    ts.strftime("%Y-%m-%d %H:%M:%S UTC"),
                    f"{importe(rng, tipo):.2f}",
                    "EUR",
                    tipo,
                    rng.choice(CANALES[tipo]),
                    elegir(rng, PAISES),
                ])
            manifiesto["filas_por_dia"][dia.isoformat()] = n
            manifiesto["total"] += n

    (salida / "manifiesto.json").write_text(json.dumps(manifiesto, indent=2), encoding="utf-8")
    return fichero, manifiesto


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--inicio", type=date.fromisoformat, default=date(2026, 6, 1))
    p.add_argument("--dias", type=int, default=90)
    p.add_argument("--filas-dia", type=int, default=24_000)
    p.add_argument("--cuentas", type=int, default=50_000)
    p.add_argument("--semilla", type=int, default=20260911)
    p.add_argument("--salida", type=Path, default=Path(__file__).parent / "data")
    a = p.parse_args()

    fichero, m = generar(a.inicio, a.dias, a.filas_dia, a.cuentas, a.semilla, a.salida)
    print(f"{m['total']:,} filas en {m['dias']} días -> {fichero} ({fichero.stat().st_size / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
