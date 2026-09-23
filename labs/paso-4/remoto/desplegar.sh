#!/usr/bin/env bash
# Paso 4 · Despliega Airflow ligero en un servidor por SSH.
#
# Uso (desde la raíz del proyecto, en Git Bash):
#   bash labs/paso-4/remoto/desplegar.sh            # alias `vps-a` de ~/.ssh/config, ssh de Git Bash
#
# Si la clave SSH tiene frase de paso y está cargada en el agente de Windows, hay que usar el cliente de
# Windows, que es el único que ve ese agente:
#   SSH=/c/Windows/System32/OpenSSH/ssh.exe SCP=/c/Windows/System32/OpenSSH/scp.exe bash labs/paso-4/remoto/desplegar.sh
#
# Qué hace, en orden:
#   1. Comprueba que hay al menos 1,5 GB de RAM disponible. Si no, para: el servidor ya corre otras cosas.
#   2. Crea ~/sdag-airflow con la carpeta de credenciales en 700.
#   3. Copia el compose y el DAG.
#   4. Copia el fichero de ADC y lo deja en 600.
#   5. Arranca el contenedor con el UID del usuario remoto.
#
# Al acabar el paso hay que ejecutar limpiar.sh: borra las credenciales del servidor.
set -euo pipefail

HOST="${HOST:-vps-a}"
SSH="${SSH:-ssh}"
SCP="${SCP:-scp}"
DIR_REMOTO="sdag-airflow"
AQUI="$(cd "$(dirname "$0")" && pwd)"
RAM_MINIMA_MB=1500
# Medido en vps-a el 2026-09-14, por lo que liberó cada paso al desmontar: la imagen ocupa ~2,9 GB en disco
# (docker image inspect decía 0,64 GB, que es el tamaño comprimido) y el contenedor ~0,55 GB con el pip del
# provider. Total ~3,4 GB. Con 3 GB de freno el disco llegó al 98 %. Se exige el doble del total medido.
DISCO_MINIMO_MB=7000

# El ssh/scp de Windows no entiende rutas de Git Bash (/d/...): se convierten a C:\... cuando hace falta.
local_path() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi; }

if [ -z "${ADC_LOCAL:-}" ]; then
  ADC_LOCAL="$(cygpath -u "$APPDATA" 2>/dev/null || echo "$APPDATA")/gcloud/application_default_credentials.json"
fi
[ -f "$ADC_LOCAL" ] || { echo "No encuentro el fichero de ADC en $ADC_LOCAL"; exit 1; }

echo "== 1. RAM disponible en $HOST"
disponible=$("$SSH" "$HOST" "free -m | awk '/^Mem:/ {print \$7}'" | tr -d '\r')
echo "   ${disponible} MB disponibles"
if [ "$disponible" -lt "$RAM_MINIMA_MB" ]; then
  echo "   Menos de ${RAM_MINIMA_MB} MB: no despliego para no tumbar lo que ya corre."
  exit 1
fi

echo "== 1b. Disco libre en $HOST"
libre=$("$SSH" "$HOST" "df -m / | awk 'NR==2 {print \$4}'" | tr -d '\r')
echo "   ${libre} MB libres"
if [ "$libre" -lt "$DISCO_MINIMO_MB" ]; then
  echo "   Menos de ${DISCO_MINIMO_MB} MB: no despliego para no llenar el disco."
  exit 1
fi

echo "== 1c. Permiso para usar Docker"
if ! "$SSH" "$HOST" "docker ps >/dev/null 2>&1"; then
  echo "   El usuario remoto no puede usar Docker sin sudo. Añádelo al grupo docker o despliega tú con sudo."
  exit 1
fi

echo "== 2. Carpetas"
"$SSH" "$HOST" "mkdir -p ~/$DIR_REMOTO/dags ~/$DIR_REMOTO/gcp && chmod 700 ~/$DIR_REMOTO/gcp"

echo "== 3. Compose y DAG"
"$SCP" -q "$(local_path "$AQUI/docker-compose.yaml")" "$HOST:$DIR_REMOTO/docker-compose.yaml"
"$SCP" -q "$(local_path "$AQUI/../dags/sdag_ingesta_diaria.py")" "$HOST:$DIR_REMOTO/dags/sdag_ingesta_diaria.py"

echo "== 4. Credenciales (600)"
"$SCP" -q "$(local_path "$ADC_LOCAL")" "$HOST:$DIR_REMOTO/gcp/application_default_credentials.json"
"$SSH" "$HOST" "chmod 600 ~/$DIR_REMOTO/gcp/application_default_credentials.json"

echo "== 5. Arranque"
# Si se entra como root (UID 0), el contenedor no debe correr como root: se usa el UID 50000 de la imagen
# oficial y se le da la propiedad del fichero de credenciales, que sigue en 600.
# No se tocan los permisos de las carpetas del host: el montaje lo resuelve el demonio de Docker (root), y dentro
# del contenedor solo cuentan el propietario y los permisos del propio fichero.
"$SSH" "$HOST" "cd ~/$DIR_REMOTO && uid=\$(id -u); if [ \"\$uid\" = 0 ]; then uid=50000; chown 50000:0 gcp/application_default_credentials.json; fi; AIRFLOW_UID=\$uid docker compose up -d"

echo
echo "Listo. La primera vez tarda unos minutos: descarga la imagen e instala el provider de Google."
echo "Interfaz, con un túnel:  ssh -L 8080:127.0.0.1:8080 $HOST   y abre http://localhost:8080"
echo "Contraseña de admin:     ssh $HOST \"docker exec sdag-airflow cat /opt/airflow/standalone_admin_password.txt\""
