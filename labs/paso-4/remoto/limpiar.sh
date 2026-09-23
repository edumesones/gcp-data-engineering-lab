#!/usr/bin/env bash
# Paso 4 · Apaga Airflow y borra las credenciales del servidor. Ejecutar al cerrar el paso.
#
# Uso:  bash labs/paso-4/remoto/limpiar.sh        (alias `vps-a` por defecto)
# Con la clave en el agente de Windows:
#   SSH=/c/Windows/System32/OpenSSH/ssh.exe bash labs/paso-4/remoto/limpiar.sh
set -euo pipefail

HOST="${HOST:-vps-a}"
SSH="${SSH:-ssh}"
DIR_REMOTO="sdag-airflow"

echo "== Parar y borrar el contenedor"
"$SSH" "$HOST" "cd ~/$DIR_REMOTO && docker compose down"

echo "== Borrar las credenciales"
"$SSH" "$HOST" "shred -u ~/$DIR_REMOTO/gcp/application_default_credentials.json 2>/dev/null \
  || rm -f ~/$DIR_REMOTO/gcp/application_default_credentials.json"

echo "== Comprobación"
if "$SSH" "$HOST" "test -e ~/$DIR_REMOTO/gcp/application_default_credentials.json"; then
  echo "   ERROR: el fichero de credenciales sigue en el servidor"
  exit 1
fi
echo "   Credenciales borradas. El DAG y el compose se quedan en ~/$DIR_REMOTO por si hay que repetir."
