#!/usr/bin/env bash

set -euo pipefail

#######################################
# description
# Arguments:
#  None
#######################################
generate_prometheus_yml() {
  local prometheus_yml_path=$1

  cat << EOF > "${prometheus_yml_path}"
global:
  scrape_interval:     15s # By default, scrape targets every 15 seconds.
  evaluation_interval: 15s # Evaluate rules every 15 seconds.

  # Attach these extra labels to all timeseries collected by this Prometheus instance.
  external_labels:
    monitor: 'codelab-monitor'

rule_files:
  - 'prometheus.rules.yml'

scrape_configs:
  - job_name: 'prometheus'

    # Override the global default and scrape targets from this job every 5 seconds.
    scrape_interval: 5s

    static_configs:
      - targets: ['localhost:9090']

  - job_name:       'node'

    # Override the global default and scrape targets from this job every 5 seconds.
    scrape_interval: 5s

    static_configs:
      - targets: ['localhost:3001', 'localhost']
        labels:
          group: 'production'

      - targets: ['localhost:8082']
        labels:
          group: 'canary'
EOF
}