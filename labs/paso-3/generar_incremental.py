"""Genera una tanda incremental para el paso 3: días nuevos, correcciones y duplicados a propósito.

Qué produce, bajo `data/`:
  transacciones/dt=YYYY-MM-DD/parte-000.csv   un fichero por día, inmutable
  manifiesto_incremental.json                 qué lleva la tanda, para que el verificador lo contraste

Tres clases de fila, que son las que hacen interesante al MERGE:
  · NUEVAS       : días posteriores al último cargado en el paso 2.
  · CORRECCIONES : ids que YA están en la tabla, con `estado` y `updated_at` nuevos. El MERGE debe actualizarlos.
  · DUPLICADAS   : la misma fila dos veces dentro de la tanda, con distinto `updated_at`. Hay que deduplicar
                   antes del MERGE o falla con "UPDATE/MERGE must match at most one source row for each target row".

Los ids de las correcciones NO se inventan: se calculan a partir de `manifiesto.json` del paso 2, que dice
cuántas filas tiene cada día. El generador del paso 2 numera las transacciones en orden, así que el rango de
ids de un día sale de la suma acumulada.

Determinista: misma semilla y mismos parámetros -> mismos ficheros.

Uso:
    python generar_incremental.py
    python generar_incremental.py --dias 1 --correcciones 3 --duplicados 2 --salida data/prueba
"""

import argparse
import csv
import json
import random
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

PASO2 = Path(__file__).resolve().parent.parent / "paso-2"
TIPOS = [("TARJETA", 0.55), ("TRANSFERENCIA", 0.20), ("DOMICILIACION", 0.12), ("RETIRADA", 0.08), ("INGRESO", 0.05)]
CANALES = {
    "TARJETA": ["APP", "WEB", "TPV"],
    "TRANSFERENCIA": ["APP", "WEB", "OFICINA"],
    "DOMICILIACION": ["SISTEMA"],
    "RETIRADA": ["CAJERO", "OFICINA"],
    "INGRESO": ["CAJERO", "OFICINA", "APP"],
}
PAISES = [("ES", 0.86), ("PT", 0.03), ("FR", 0.03), ("DE", 0.02), ("GB", 0.02), ("US", 0.02), ("MX", 0.01), ("AE", 0.01)]
COLUMNAS = ["transaccion_id", "cuenta_id", "fecha", "ts_operacion", "importe", "divisa", "tipo", "canal",
            "pais_contraparte", "estado", "updated_at"]


def elegir(rng, opciones):
    valores, pesos = zip(*opciones)
    return rng.choices(valores, weights=pesos, k=1)[0]


def importe(rng, tipo):
    mu, sigma = {"TARJETA": (3.0, 0.9), "TRANSFERENCIA": (5.5, 1.2), "DOMICILIACION": (4.2, 0.6),
                 "RETIRADA": (4.0, 0.7), "INGRESO": (6.0, 1.0)}[tipo]
    valor = round(min(rng.lognormvariate(mu, sigma), 250_000), 2)
    return valor if tipo == "INGRESO" else -valor


def ts_utc(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S UTC")


def rangos_de_id_del_paso2(manifiesto_paso2):
    """{fecha: (primer_id, ultimo_id)} a partir de las filas por día del paso 2."""
    rangos, acumulado = {}, 0
    for dia, n in sorted(manifiesto_paso2["filas_por_dia"].items()):
        rangos[dia] = (acumulado + 1, acumulado + n)
        acumulado += n
    return rangos, acumulado


def fila_nueva(rng, secuencia, dia, n_cuentas, corte):
    tipo = elegir(rng, TIPOS)
    ts = datetime(dia.year, dia.month, dia.day, tzinfo=timezone.utc) + timedelta(seconds=rng.randrange(86_400))
    return {
        "transaccion_id": f"TX{secuencia:010d}",
        "cuenta_id": f"CU{rng.randrange(1, n_cuentas + 1):07d}",
        "fecha": dia.isoformat(),
        "ts_operacion": ts_utc(ts),
        "importe": f"{importe(rng, tipo):.2f}",
        "divisa": "EUR",
        "tipo": tipo,
        "canal": rng.choice(CANALES[tipo]),
        "pais_contraparte": elegir(rng, PAISES),
        # Las del último día llegan sin liquidar: dan pie a una corrección posterior.
        "estado": "PENDIENTE" if dia == corte else "LIQUIDADA",
        "updated_at": ts_utc(ts + timedelta(hours=2)),
    }


def generar(inicio, dias, filas_dia, n_cuentas, n_correcciones, n_duplicados, semilla, salida):
    rng = random.Random(semilla)
    manifiesto_paso2 = json.loads((PASO2 / "data" / "manifiesto.json").read_text(encoding="utf-8"))
    rangos, ultimo_id = rangos_de_id_del_paso2(manifiesto_paso2)

    filas_por_dia, correcciones, duplicados = {}, [], []
    secuencia = ultimo_id
    corte = inicio + timedelta(days=dias - 1)

    # 1) Días nuevos.
    for d in range(dias):
        dia = inicio + timedelta(days=d)
        factor = rng.uniform(0.8, 1.2) * (0.7 if dia.weekday() >= 5 else 1.0)
        filas = []
        for _ in range(int(filas_dia * factor)):
            secuencia += 1
            filas.append(fila_nueva(rng, secuencia, dia, n_cuentas, corte))
        filas_por_dia[dia.isoformat()] = filas

    # 2) Correcciones sobre días que YA están cargados: se devuelven operaciones antiguas.
    #    Van en el fichero del día al que pertenecen, porque `fecha` es la columna de partición.
    dias_antiguos = sorted(rangos)[-2:]
    for i in range(n_correcciones):
        dia_ant = dias_antiguos[i % len(dias_antiguos)]
        primero, ultimo = rangos[dia_ant]
        id_corregido = f"TX{rng.randrange(primero, ultimo + 1):010d}"
        base = datetime.fromisoformat(dia_ant).replace(tzinfo=timezone.utc)
        fila = {
            "transaccion_id": id_corregido,
            "cuenta_id": "",             # el MERGE no toca estas columnas: solo estado e importe
            "fecha": dia_ant,
            "ts_operacion": ts_utc(base + timedelta(hours=12)),
            "importe": "0.00",
            "divisa": "EUR",
            "tipo": "TARJETA",
            "canal": "APP",
            "pais_contraparte": "ES",
            "estado": "DEVUELTA",
            "updated_at": ts_utc(datetime(2026, 9, 2, 8, 0, 0, tzinfo=timezone.utc) + timedelta(minutes=i)),
        }
        filas_por_dia.setdefault(dia_ant, []).append(fila)
        correcciones.append({"transaccion_id": id_corregido, "fecha": dia_ant, "estado": "DEVUELTA",
                             "updated_at": fila["updated_at"]})

    # 3) Duplicados dentro de la tanda: la misma clave dos veces, con updated_at distinto.
    #    Gana el más reciente. Sin deduplicar, el MERGE falla.
    dia_corte = corte.isoformat()
    for i in range(n_duplicados):
        original = filas_por_dia[dia_corte][i]
        copia = dict(original)
        copia["estado"] = "LIQUIDADA"
        copia["updated_at"] = ts_utc(datetime.fromisoformat(dia_corte).replace(tzinfo=timezone.utc)
                                     + timedelta(days=1, hours=i))
        filas_por_dia[dia_corte].append(copia)
        duplicados.append({"transaccion_id": original["transaccion_id"],
                           "updated_at_gana": copia["updated_at"],
                           "updated_at_pierde": original["updated_at"]})

    # Escritura: un fichero por día, en una ruta con el día en el nombre.
    salida.mkdir(parents=True, exist_ok=True)
    ficheros = {}
    for dia, filas in sorted(filas_por_dia.items()):
        carpeta = salida / "transacciones" / f"dt={dia}"
        carpeta.mkdir(parents=True, exist_ok=True)
        destino = carpeta / "parte-000.csv"
        with destino.open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=COLUMNAS)
            w.writeheader()
            w.writerows(filas)
        ficheros[dia] = {"ruta": str(destino.relative_to(salida)), "filas": len(filas)}

    manifiesto = {
        "semilla": semilla,
        "generado": datetime.now(timezone.utc).isoformat(),
        "ultimo_id_del_paso2": f"TX{ultimo_id:010d}",
        "dias_nuevos": [(inicio + timedelta(days=d)).isoformat() for d in range(dias)],
        "ficheros": ficheros,
        "filas_totales": sum(v["filas"] for v in ficheros.values()),
        "filas_nuevas": sum(len(v) for k, v in filas_por_dia.items() if k in
                            {(inicio + timedelta(days=d)).isoformat() for d in range(dias)}) - n_duplicados,
        "correcciones": correcciones,
        "duplicados": duplicados,
    }
    (salida / "manifiesto_incremental.json").write_text(json.dumps(manifiesto, indent=2, ensure_ascii=False),
                                                        encoding="utf-8")
    return manifiesto


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--inicio", type=date.fromisoformat, default=date(2026, 8, 30),
                   help="primer día nuevo (el paso 2 llega hasta 2026-08-29)")
    p.add_argument("--dias", type=int, default=3)
    p.add_argument("--filas-dia", type=int, default=24_000)
    p.add_argument("--cuentas", type=int, default=50_000)
    p.add_argument("--correcciones", type=int, default=40)
    p.add_argument("--duplicados", type=int, default=5)
    p.add_argument("--semilla", type=int, default=20260912)
    p.add_argument("--salida", type=Path, default=Path(__file__).parent / "data")
    a = p.parse_args()

    m = generar(a.inicio, a.dias, a.filas_dia, a.cuentas, a.correcciones, a.duplicados, a.semilla, a.salida)
    print(f"{m['filas_totales']:,} filas en {len(m['ficheros'])} ficheros")
    print(f"  nuevas       : {m['filas_nuevas']:,}")
    print(f"  correcciones : {len(m['correcciones'])} (sobre días ya cargados)")
    print(f"  duplicados   : {len(m['duplicados'])} claves repetidas dentro de la tanda")
    print(f"-> {a.salida}")


if __name__ == "__main__":
    main()
