#!/bin/bash
# Ejecutar el comando de AWS SSO para el perfil 'shared-services'
aws sso login --profile shared-services
# Ejecutar el comando de AWS SSO para el perfil 'prendarios-dev'
aws sso login --profile prendarios-dev
# Ejecutar el comando de AWS SSO para el perfil 'agropj'
#aws sso login --profile agropj
aws sso login --profile core-prendarios
# Ejecutar el comando de AWS SSO para el perfil 'core-prendarios-account'
aws sso login --profile core-prendarios-account
# Esperar 5 segundos antes de continuar con el siguiente comando
sleep 1
# Ejecutar el comando de AWS CodeArtifact para el perfil 'shared-services'
aws codeartifact login --tool npm --repository npm-sc --domain sc --domain-owner 014881332177 --region us-east-1 --profile shared-services
# Esperar 5 segundos antes de continuar con el siguiente comando
sleep 5
# Ejecutar el comando de AWS SSO para el perfil 'pofile-front'
aws sso login --profile pofile-front
# Ejecutar el comando de AWS SSO para el perfil 'LupitaDev'
aws sso login --profile LupitaDev
# Ejecutar el comando de AWS SSO para el perfil 'Biometria Prendarios'
aws sso login --profile biometria-prendarios
# Ejecutar el comando de AWS SSO para el perfil 'Biometry Account Dev'
aws sso login --profile biometry-account
# Ejecutar el comando de AWS SSO para el perfil 'Autogestivo Account Dev'
aws sso login --profile autogestivo-account
