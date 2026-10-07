#!/usr/bin/env bash
# =============================================================================
#  SCRIPT : 44_prometheus_metrics_exporter.sh
#  LEVEL  : Advanced
#  PURPOSE: Generate Prometheus-compliant node metrics in pure Bash
#  USAGE  : bash 44_prometheus_metrics_exporter.sh [METRICS_OUTPUT_FILE]
#           bash 44_prometheus_metrics_exporter.sh /tmp/node_metrics.prom
#
#  CONCEPTS COVERED:
#    - Prometheus text-based exposition format specification (HELP & TYPE)
#    - Gauge and Counter metric definitions
#    - System telemetry extraction (load, RAM, disk, process count)
#    - Integration with prometheus-node-exporter textfile collector
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
