#!/bin/bash
# Builds a deployable Azure Functions custom handler package for Data API builder.
#
# Output: dist/dab-function-app.zip, containing host.json, the catch-all HTTP function,
# dab-config.json and a self-contained Linux build of the DAB engine under engine/.
#
# Run on Linux, macOS or WSL so the engine keeps its executable bit inside the zip.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUNTIME_IDENTIFIER="${RUNTIME_IDENTIFIER:-linux-x64}"
CONFIGURATION="${CONFIGURATION:-Release}"
DAB_CONFIG_FILE="${DAB_CONFIG_FILE:-$SCRIPT_DIR/dab-config.json}"

STAGING_DIR="$SCRIPT_DIR/dist/package"
ZIP_FILE="$SCRIPT_DIR/dist/dab-function-app.zip"

echo "cleaning previous output"
rm -rf "$SCRIPT_DIR/dist" "$SCRIPT_DIR/engine"
mkdir -p "$STAGING_DIR"

echo "publishing Data API builder engine ($RUNTIME_IDENTIFIER, self-contained)"
dotnet publish "$REPO_ROOT/src/Service/Azure.DataApiBuilder.Service.csproj" \
    --configuration "$CONFIGURATION" \
    --runtime "$RUNTIME_IDENTIFIER" \
    --self-contained true \
    --output "$SCRIPT_DIR/engine"

chmod +x "$SCRIPT_DIR/engine/Azure.DataApiBuilder.Service"

# The engine ships with a sample dab-config.json; the Function App uses the one at the app root.
rm -f "$SCRIPT_DIR/engine/dab-config.json"

echo "staging Function App files"
cp "$SCRIPT_DIR/host.json" "$STAGING_DIR/"
cp -r "$SCRIPT_DIR/dab" "$STAGING_DIR/"
cp -r "$SCRIPT_DIR/engine" "$STAGING_DIR/"
cp "$DAB_CONFIG_FILE" "$STAGING_DIR/dab-config.json"

echo "creating $ZIP_FILE"
(cd "$STAGING_DIR" && zip -q -r -X "$ZIP_FILE" .)

echo "done"
