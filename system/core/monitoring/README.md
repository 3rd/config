# core.monitoring

`core.monitoring` is a small NixOS monitoring stack.

It wires together:

- persistent `journald`
- `auditd` rules for exec, outbound connect, and targeted filesystem writes
- a Prometheus-backed process sampler for CPU, memory, and disk usage monitoring
- a long-lived audit stream exporter that backfills once, then consumes `audisp-af_unix` events live through a bounded socket queue, appends raw groups to a local spool, and normalizes from that spool asynchronously
- a timer-driven network-usage exporter that normalizes per-process traffic samples into NDJSON
- compact audit summary streams so default Grafana leaderboard/stat panels do not rescan raw audit logs every refresh
- local `prometheus` metrics storage for process history panels
- local `loki` storage
- local `alloy` ingestion from the journal and exporter output
- local `grafana` dashboards for triage, process leaders, event exploration, network attribution, and filesystem activity

## Primary Operators

- `systemctl status auditd alloy loki prometheus grafana core-monitoring-process-metrics-exporter`
- `systemctl status core-monitoring-audit-stream-exporter core-monitoring-network-usage-export.timer`
- `journalctl --since yesterday`
- `journalctl --since "2026-04-01 03:00" --until "2026-04-01 03:15"`
- `ausearch -k exec -ts yesterday`
- `ausearch -k net_connect -ts yesterday`
- `ausearch -k fs_system -ts yesterday`
- `ausearch -k fs_home -ts yesterday`

## Local Endpoints

- Grafana (default): `http://127.0.0.1:12210`
- Loki (default): `http://127.0.0.1:12211`
- Prometheus (default): `http://127.0.0.1:12212`
- Alloy debug UI (default): `http://127.0.0.1:12213`

Ports are configurable under `core.monitoring.ports`.

## Runtime Layout

- Service modules:
  - `journald.nix`
  - `auditd.nix`
  - `collectors.nix`
  - `prometheus.nix`
  - `loki.nix`
  - `alloy.nix`
  - `grafana.nix`
- Runtime state:
  - normalized logs: `/var/log/core-monitoring`
  - audit summary logs: `/var/log/core-monitoring/audit-*-summary-YYYYMMDD.ndjson`
  - collector state: `/var/lib/core-monitoring/state`
  - raw live audit spool: `/var/lib/core-monitoring/state/spool`
  - spool offsets: `/var/lib/core-monitoring/state/audit-spool-offsets.json`
  - Grafana secret key: `/var/lib/grafana/secret_key`
  - Loki data: `/var/lib/core-monitoring/loki`
  - Prometheus data: `/var/lib/prometheus2/data`
  - Alloy data: `/var/lib/alloy`

## Rollout

```bash
make nix
systemctl status auditd
systemctl status alloy
systemctl status loki
systemctl status prometheus
systemctl status grafana
systemctl status core-monitoring-process-metrics-exporter
```

## Notes

- `loki.source.journal.max_age` follows `core.monitoring.retention.journalDays`, so Alloy backfills the same window that journald is configured to retain.
- `systemd-journald-audit.socket` is disabled when `core.monitoring` is enabled, so audit traffic stays in `/var/log/audit` instead of also flooding persistent journald.
- the audit pipeline is stream-driven after startup backfill; the live socket reader only spools raw groups, and normalization runs asynchronously from the local spool. only network-usage remains timer-driven by default.
- default aggregate dashboards read the compact `audit_*_summary` streams, while raw event logs and explorers still read the full `audit_*` streams.
- raw `/var/log/audit/audit.log` is retained for `ausearch`, but it is not ingested into Loki.
- `core.monitoring.audit.includeLocalSocketConnects` defaults to `false`, so normalized `audit_net*` streams drop local socket chatter like `/var/run/nscd/socket` while raw audit logs still keep it.
- routine low-priority logs from the monitoring stack itself are intentionally dropped before they reach Loki, but they remain available in local journald.
- the default journal cap is `1G`, journald retention is `14d`, and the default process-metrics sample interval is `15s`.
- `core.monitoring.audit.dispatcherQueueDepth` defaults to `16384` and is passed to `audisp-af_unix` as the socket queue depth.
- `core.monitoring.audit.streamChannelCapacity` defaults to `16384` and sizes the exporter buffer between the live audit socket and normalization pipeline.
- batch-oriented monitoring services run with low CPU and IO priority so desktop work wins under build load, while the live audit stream consumer stays latency-sensitive.
- raw audit retention is bounded by rotation size and file count: `64MB` per file and `30` rotated files by default. On noisy hosts this can be much shorter than `30d`.
- normalized exporter output under `/var/log/core-monitoring` is kept for `30d` by `systemd-tmpfiles-clean`, which runs daily.
- Prometheus retention is `14d` by default and follows `core.monitoring.retention.prometheusDays`.
- Loki retention is `14d`.
