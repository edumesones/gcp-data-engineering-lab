# Cargar SIEMPRE antes de usar gcloud o bq en este proyecto:  . .\entorno.ps1
# Apunta a la configuracion del laboratorio sin tocar la activa global de la maquina.
$env:CLOUDSDK_ACTIVE_CONFIG_NAME = "sdag-lab"
$env:CLOUDSDK_PYTHON = "C:\Users\<usuario>\AppData\Local\Programs\Python\Python312\python.exe"
Write-Host "gcloud -> configuracion: $env:CLOUDSDK_ACTIVE_CONFIG_NAME"
