# Cargar SIEMPRE antes de usar gcloud o bq en este proyecto:  source entorno.sh
# Apunta a la configuracion del laboratorio sin tocar la activa global de la maquina.
export CLOUDSDK_ACTIVE_CONFIG_NAME=sdag-lab
export CLOUDSDK_PYTHON="C:\Users\<usuario>\AppData\Local\Programs\Python\Python312\python.exe"
echo "gcloud -> configuracion: $CLOUDSDK_ACTIVE_CONFIG_NAME"
