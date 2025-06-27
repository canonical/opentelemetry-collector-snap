#!/usr/bin/env bash
#
# Script to generate a valid OCB manifest for a custom OpenTelemetry Collector.
#
# Usage:
# ./generate_manifest.sh <VERSION_TAG> <VERSIONS_DIR> <ADDITIONS_FILE_PATH>
#
# Example:
# ./generate_manifest.sh v0.100.0 ./versions/0.100.0 ./manifest-additions.yaml

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Argument Validation ---
if [ "$#" -ne 3 ]; then
    echo "Illegal number of parameters. Usage:"
    echo "./generate_manifest.sh <VERSION_TAG> <VERSIONS_DIR> <ADDITIONS_FILE_PATH>"
    exit 1
fi

# --- Assign arguments to variables for readability ---
VERSION_TAG="$1"
VERSIONS_DIR="$2"
ADDITIONS_FILE="$3"

# --- Derived Variables ---
VERSION=$(echo "${VERSION_TAG}" | sed 's/v//') # Remove 'v' from tag
DIST_NAME="otelcol"
MANIFEST_FILE="${VERSIONS_DIR}/manifest.yaml"
CORE_MANIFEST_FILE="${VERSIONS_DIR}/manifest-core.yaml"
CONTRIB_MANIFEST_FILE="${VERSIONS_DIR}/manifest-contrib.yaml"
COMPONENTS_FILE="${VERSIONS_DIR}/components.yaml"
BUILD_OUTPUT_DIR="./_build"

echo "--- Generating final OCB manifest at ${MANIFEST_FILE} ---"

# Step A: Merge and filter components (core, contrib, additions) and
#          remove the original 'dist' section. Save to a temporary file.
yq eval-all 'select(fileIndex == 0) as $core | select(fileIndex == 1) as $contrib | select(fileIndex == 2) as $additions | $contrib | with_entries(.value |= map(select(.gomod | contains($additions.*.[])))) as $filtered | $filtered *+ $core' \
    "${CORE_MANIFEST_FILE}" "${CONTRIB_MANIFEST_FILE}" "${ADDITIONS_FILE}"  > "${COMPONENTS_FILE}"

# Step B: Create the final manifest starting with OUR 'dist' section.
printf "dist:\n  name: %s\n  description: 'OpenTelemetry Collector'\n  version: '%s'\n  output_path: %s\n\n" "${DIST_NAME}" "${VERSION}" "${BUILD_OUTPUT_DIR}" > "${MANIFEST_FILE}"

cat "${COMPONENTS_FILE}" > "${MANIFEST_FILE}"
cp "${MANIFEST_FILE}" snap/manifest.yaml
rm "${COMPONENTS_FILE}"

echo "--- Valid and complete manifest generated. ---"
