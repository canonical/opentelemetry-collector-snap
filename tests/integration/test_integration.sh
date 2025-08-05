#!/bin/bash

set -eux

MAX_RETRIES=24
INTERVAL=5
COUNT=0
OTEL_DIR="/etc/otelcol"
OTEL_CONFIG_DIR="${OTEL_DIR}/config.d"
PROMETHEUS_CONFIG="tests/integration/prometheus_config.yaml"
PROMETHEUS_CONFIG="tests/integration/pyroscope_config.yaml"
PROM_ENDPOINT="localhost:9090/api/v1/query"
PYRO_ENDPOINT="localhost:4040/pyroscope/render"
PROM_QUERY='query=count({__name__="node_cpu_seconds_total"})'
PYRO_QUERY='query=process_cpu:cpu:nanoseconds:cpu:nanoseconds{process_executable_path=\"/tmp/prometheus\"}'

setup() {
    sudo apt install -y snapd
    sudo snap install snapd
    sudo snap install node-exporter --classic --edge
    # download prometheus server
    curl -L -O --create-dirs --output-dir /tmp https://github.com/prometheus/prometheus/releases/download/v3.2.0/prometheus-3.2.0.linux-amd64.tar.gz
    tar -zxvf /tmp/prometheus-3.2.0.linux-amd64.tar.gz -C /tmp
    mv /tmp/prometheus-3.2.0.linux-amd64/prometheus /tmp
    # download pyroscope server
    curl -L -O --create-dirs --output-dir /tmp https://github.com/grafana/pyroscope/releases/download/v1.14.0/pyroscope_1.14.0_linux_amd64.tar.gz
    tar -zxvf /tmp/pyroscope_1.14.0_linux_amd64.tar.gz -C /tmp # now there's a /tmp/pyroscope binary already
    mkdir -p /tmp/pyroscope-data # on-disk storage
    # download and build ebpf-profiler
    git clone https://github.com/open-telemetry/opentelemetry-ebpf-profiler --depth 1
    cd opentelemetry-ebpf-profiler 
    make agent  # note: requires docker
    mv ./ebpf-profiler /tmp/ebpf-profiler
    cd ..
    sudo rm -rf ./opentelemetry-ebpf-profiler
    sudo snap install snapcraft --classic --stable
    snapcraft pack
    sudo snap install ./*.snap --dangerous
    sudo mkdir -p /etc/otelcol/config.d
    sudo cp tests/integration/otel_config.yaml "${OTEL_CONFIG_DIR}/config-01.yaml"
    sudo cp tests/integration/otel_config.yaml "${OTEL_CONFIG_DIR}/config-02.yaml"
    # run prometheus
    /tmp/prometheus --web.enable-remote-write-receiver --config.file "${PROMETHEUS_CONFIG}" --storage.tsdb.path=/tmp &
    # run pyroscope
    /tmp/pyroscope -config.file "${PYROSCOPE_CONFIG}" -target=all &
    # run otel collector
    sudo snap connect opentelemetry-collector:etc-otelcol-config
    sudo snap set opentelemetry-collector feature-gates="service.profilesSupport"
    sudo snap restart opentelemetry-collector
    # run ebpf profiler (needs otelcol to be up already)
    sudo /tmp/ebpf-profiler -collection-agent localhost:4317 -disable-tls &
}

setup

prom_fail=1

while [ "$COUNT" -lt "$MAX_RETRIES" ]; do
    json_data=$(curl -s --data-urlencode "${PROM_QUERY}" "${PROM_ENDPOINT}")
    value=$(echo "$json_data" | jq -r '.data.result[0].value[1]')

    if [ "$value" -gt 0 ] 2>/dev/null; then
        prom_fail=0
        break
    fi
    echo "[${COUNT}] Waiting for metrics to be pushed..."
    COUNT=$((COUNT + 1))
    sleep "$INTERVAL"
done

if [ "$prom_fail" -gt 0 ];  then
    echo "❌ Metrics were not pushed to Prometheus."
else 
    echo "✅ Metrics pushed to Prometheus!"
fi 

pyro_fail=1

while [ "$COUNT" -lt "$MAX_RETRIES" ]; do
    json_data=$(curl -s curl --get --data-urlencode "$PYRO_QUERY" --data-urlencode "from=now-1h" "$PYRO_ENDPOINT")
    # this indicates that there's some process activity detected
    value=$(echo "$json_data" | jq -r '.flamebearer.levels[0] | add')

    if [ "$value" -gt 0 ] 2>/dev/null; then
        pyro_fail=0
        break
    fi
    echo "[${COUNT}] Waiting for profiles to be pushed..."
    COUNT=$((COUNT + 1))
    sleep "$INTERVAL"
done

if [ "$pyro_fail" -gt 0 ];  then
    echo "❌ Profiles were not pushed to Pyroscope."
else 
    echo "✅ Profiles pushed to Pyroscope!"
fi 

# cleanup
echo "Cleaning up..."
sudo snap remove --purge opentelemetry-collector

exit $("$prom_fail" + "$pyro_fail")

