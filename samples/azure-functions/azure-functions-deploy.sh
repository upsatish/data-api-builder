#!/bin/bash
# Deploys Data API builder to an Azure Function App (Linux) as a custom handler.
# Requires: Azure CLI (az login), .NET SDK, zip.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

FILE=".env"
if [[ -f $FILE ]]; then
    echo "loading from .env"
    set -a
    # shellcheck disable=SC1090
    source "$FILE"
    set +a
else
    cat << 'ENVEOF' > .env
RESOURCE_GROUP=""
LOCATION=""
STORAGE_ACCOUNT=""
FUNCTION_APP_NAME=""
APP_SERVICE_PLAN="dab-functions-plan"
# B1/S1/P1v3 (Dedicated) or EP1/EP2/EP3 (Elastic Premium)
PLAN_SKU="B1"
DAB_CONFIG_FILE="./dab-config.json"
DATABASE_CONNECTION_STRING=""
ENVEOF
    echo "Environment file (.env) not detected."
    echo "Please configure values for your environment in the created .env file and run the script again."
    exit 1
fi

: > log.txt

echo "building package" | tee -a log.txt
DAB_CONFIG_FILE="$DAB_CONFIG_FILE" ./build.sh >> log.txt

echo "creating resource group '$RESOURCE_GROUP'" | tee -a log.txt
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" -o json >> log.txt

echo "creating storage account '$STORAGE_ACCOUNT'" | tee -a log.txt
az storage account create --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" --sku Standard_LRS -o json >> log.txt

echo "creating Linux plan '$APP_SERVICE_PLAN' ($PLAN_SKU)" | tee -a log.txt
if [[ "$PLAN_SKU" == EP* ]]; then
    az functionapp plan create --name "$APP_SERVICE_PLAN" --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" --sku "$PLAN_SKU" --is-linux true -o json >> log.txt
else
    az appservice plan create --name "$APP_SERVICE_PLAN" --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" --sku "$PLAN_SKU" --is-linux -o json >> log.txt
fi

echo "creating Function App '$FUNCTION_APP_NAME' (custom handler)" | tee -a log.txt
az functionapp create --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" \
    --plan "$APP_SERVICE_PLAN" --storage-account "$STORAGE_ACCOUNT" \
    --os-type Linux --runtime custom --functions-version 4 -o json >> log.txt

echo "configuring app settings" | tee -a log.txt
az functionapp config appsettings set --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" \
    --settings "DATABASE_CONNECTION_STRING=$DATABASE_CONNECTION_STRING" -o none >> log.txt

echo "deploying package" | tee -a log.txt
az functionapp deployment source config-zip --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" \
    --src "dist/dab-function-app.zip" -o json >> log.txt

HOST_NAME=$(az functionapp show --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" --query defaultHostName -o tsv)
echo "Data API builder deployed: https://$HOST_NAME" | tee -a log.txt
echo "Enable App Service Authentication (EasyAuth) on the Function App before calling authenticated entities." | tee -a log.txt
