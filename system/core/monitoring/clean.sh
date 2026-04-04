#!/usr/bin/env bash
set -euf -o pipefail

sudo systemctl stop \
  core-monitoring-audit-stream-exporter.service \
  core-monitoring-network-usage-export.timer \
  core-monitoring-network-usage-export.service \
  core-monitoring-process-metrics-exporter.service \
  alloy.service loki.service grafana.service prometheus.service auditd.service

sudo rm -rf /var/log/core-monitoring/* /var/lib/core-monitoring/loki/* /var/lib/core-monitoring/state/* /var/lib/alloy/* /var/lib/prometheus2/data/*
sudo rm -f /var/log/audit/audit.log*
sudo journalctl --rotate
sudo journalctl --vacuum-time=1s

sudo systemctl start auditd.service prometheus.service loki.service alloy.service grafana.service
sudo systemctl start core-monitoring-process-metrics-exporter.service
sudo systemctl start core-monitoring-audit-stream-exporter.service
sudo systemctl start \
  core-monitoring-network-usage-export.timer
