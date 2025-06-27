.PHONY: all snap update-version generate-manifest prepare-dir integration

# --- Directory and Name Variables ---
VERSION_TAG ?= "v0.100.0"
VERSION     = $(subst v,,$(VERSION_TAG))
VERSIONS_DIR    := ./versions/$(VERSION)
MANIFEST_FILE   := $(VERSIONS_DIR)/manifest.yaml
PROJECT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
TESTS := $(PROJECT)tests
ALL := $(SRC) $(TESTS)

export PYTHONPATH = $(PROJECT)
export PY_COLORS=1

# --- URLs ---
BASE_MANIFEST_URL := https://raw.githubusercontent.com/open-telemetry/opentelemetry-collector-releases/refs/tags/$(VERSION_TAG)/distributions

# --- Main Targets ---

all: snap

snap: update-version
	@echo "Packing OpenTelemetry Collector snap for version $(VERSION)..."
	@snapcraft pack --debug --verbosity debug


update-version: generate-manifest
	@echo "Updating snap/snapcraft.yaml to version $(VERSION)..."
	@yq eval \
	  '.version = "$(VERSION)" | .parts.ocb["source-tag"] = "v$(VERSION)"' \
	  -i snap/snapcraft.yaml

generate-manifest: $(VERSIONS_DIR)/manifest-core.yaml $(VERSIONS_DIR)/manifest-contrib.yaml $(VERSIONS_DIR)/config.yaml
	@./generate_manifest.sh $(VERSION_TAG) $(VERSIONS_DIR) ./manifest-additions.yaml

# Download base manifests if they don't exist.
$(VERSIONS_DIR)/manifest-core.yaml: prepare-dir
	@echo "--- Downloading 'core' manifest for version $(VERSION_TAG) ---"
	@wget "$(BASE_MANIFEST_URL)/otelcol/manifest.yaml" -O $@ --quiet || \
		(echo "Error: Could not download core manifest for $(VERSION_TAG)."; exit 1)

$(VERSIONS_DIR)/manifest-contrib.yaml: prepare-dir
	@echo "--- Downloading 'contrib' manifest for version $(VERSION_TAG) ---"
	@wget "$(BASE_MANIFEST_URL)/otelcol-contrib/manifest.yaml" -O $@ --quiet || \
		(echo "Error: Could not download contrib manifest for $(VERSION_TAG)."; exit 1)

$(VERSIONS_DIR)/config.yaml: prepare-dir
	@echo "--- Downloading 'core' config file for version $(VERSION_TAG) ---"
	@wget "$(BASE_MANIFEST_URL)/otelcol/config.yaml" -O $@ --quiet || \
		(echo "Error: Could not download core config for $(VERSION_TAG)."; exit 1)
	@cp $@ snap/config.yaml

# Prepares the version directory for a specific version.
prepare-dir:
	@echo "--- Preparing build directory: $(VERSIONS_DIR) ---"
	@mkdir -p $(VERSIONS_DIR)
	@cp manifest-additions.yaml $(VERSIONS_DIR)/manifest-additions.yaml


# Run integration tests
integration:
	sh tests/integration/test_integration.sh