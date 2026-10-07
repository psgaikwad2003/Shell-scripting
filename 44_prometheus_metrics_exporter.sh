#!/usr/bin/env bash
# =============================================================================
# Script: 44_prometheus_metrics_exporter.sh
# Problem Statement: Extract system metrics in pure Bash and expose them formatted according to the Prometheus exposition text standard.
# =============================================================================

set -euo pipefail

OUT_FILE="${1:-/tmp/node_metrics.prom}"

generate_metrics() {
    local TIMESTAMP_MS
    TIMESTAMP_MS=$(date +%s%3N 2>/dev/null || echo "$(date +%s)000")

    local PROC_COUNT
    PROC_COUNT=$(ps -e 2>/dev/null | wc -l || echo 0)

    cat << EOF > "$OUT_FILE"
# HELP node_custom_process_count Current number of active processes
# TYPE node_custom_process_count gauge
node_custom_process_count $PROC_COUNT

# HELP node_custom_exporter_scrape_timestamp Exporter last scrape timestamp
# TYPE node_custom_exporter_scrape_timestamp counter
node_custom_exporter_scrape_timestamp $TIMESTAMP_MS

# HELP node_custom_health_status Status indicator of node monitoring
# TYPE node_custom_health_status gauge
node_custom_health_status 1
EOF

    echo "Prometheus metrics written to: $OUT_FILE"
    cat "$OUT_FILE"
}

generate_metrics
