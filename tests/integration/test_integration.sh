#!/bin/bash

set -eux

MAX_RETRIES=24
INTERVAL=5
COUNT=0
OTEL_DIR="/etc/otelcol"
OTEL_CONFIG="${OTEL_DIR}/config.d/config.yaml"
PROMETHEUS_CONFIG="tests/integration/prometheus_config.yaml"
ENDPOINT="localhost:9090/api/v1/query"
QUERY='query=count({__name__="node_cpu_seconds_total"})'

setup() {
    sudo apt install -y snapd
    sudo snap install snapd
    sudo snap install node-exporter --classic --edge
    curl -L -O --create-dirs --output-dir /tmp https://github.com/prometheus/prometheus/releases/download/v3.2.0/prometheus-3.2.0.linux-amd64.tar.gz
    tar -zxvf /tmp/prometheus-3.2.0.linux-amd64.tar.gz -C /tmp
    mv /tmp/prometheus-3.2.0.linux-amd64/prometheus /tmp
    sudo snap install snapcraft --classic --stable
    snapcraft pack
    sudo snap install ./*.snap --dangerous
    sudo mkdir -p /etc/otelcol/config.d
    sudo cp tests/integration/otel_config.yaml "${OTEL_CONFIG}"

    /tmp/prometheus --web.enable-remote-write-receiver --config.file "${PROMETHEUS_CONFIG}" --storage.tsdb.path=/tmp &
    sudo snap connect opentelemetry-collector:etc-otelcol-config
    sudo snap restart opentelemetry-collector
}

setup

while [ "$COUNT" -lt "$MAX_RETRIES" ]; do
    json_data=$(curl -s --data-urlencode "${QUERY}" "${ENDPOINT}")
    value=$(echo "$json_data" | jq -r '.data.result[0].value[1]')

    if [ "$value" -gt 0 ] 2>/dev/null; then
        echo "✅ Metrics pushed to Prometheus!"
        exit 0
    fi
    echo "[${COUNT}] Waiting for metrics to be pushed..."
    COUNT=$((COUNT + 1))
    sleep "$INTERVAL"
done

echo "❌ Metrics were not pushed to Prometheus."
exit 1
