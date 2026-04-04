{ lib }:
{
  cfg,
  host,
  hostClass,
}:
let
  quote = builtins.toJSON;

  renderList = values: "[${lib.concatStringsSep ", " values}]";

  renderStringList = values: renderList (map quote values);

  renderMap =
    attrs:
    "{ ${lib.concatStringsSep ", " (lib.mapAttrsToList (name: value: "${quote name} = ${quote value}") attrs)} }";

  renderTarget = path: labels: "${renderMap ({ "__path__" = path; } // labels)},";

  baseLabels = {
    host = host;
    host_class = hostClass;
  } // cfg.labels;

  journalLabels = baseLabels // {
    component = "journal";
  };

  auditLabels = baseLabels // {
    component = "audit";
    job = "auditd";
  };

  auditFsLabels = baseLabels // {
    component = "audit_fs";
    job = "audit-fs";
  };

  auditFsSummaryLabels = baseLabels // {
    component = "audit_fs_summary";
    job = "audit-fs-summary";
  };

  auditExecLabels = baseLabels // {
    component = "audit_exec";
    job = "audit-exec";
  };

  auditExecSummaryLabels = baseLabels // {
    component = "audit_exec_summary";
    job = "audit-exec-summary";
  };

  auditNetLabels = baseLabels // {
    component = "audit_net";
    job = "audit-net";
  };

  auditNetSummaryLabels = baseLabels // {
    component = "audit_net_summary";
    job = "audit-net-summary";
  };

  netUsageLabels = baseLabels // {
    component = "net_usage";
    job = "net-usage";
  };

  anomalyLabels = baseLabels // {
    component = "anomaly";
    job = "anomaly";
  };

  monitoringJournalUnitPattern =
    "(alloy[.]service|auditd[.]service|core-monitoring-.*|grafana[.]service|loki[.]service|prometheus[.]service)";

  hasNormalizedCollectors =
    cfg.collectors.auditFs.enable
    || cfg.collectors.auditExec.enable
    || cfg.collectors.auditNet.enable
    || cfg.collectors.networkUsage.enable;
in ''
  logging {
    format = "logfmt"
    level  = "warn"
  }

  livedebugging {
    enabled = true
  }

  loki.write "local" {
    endpoint {
      url = ${quote "http://127.0.0.1:${toString cfg.ports.loki}/loki/api/v1/push"}
    }
  }

  loki.process "audit" {
    forward_to = [loki.write.local.receiver]

    stage.regex {
      expression = "(?:^| )type=(?P<audit_type>[A-Z_]+)(?: |$)"
    }

    stage.regex {
      expression = "(?:^| )key=\\\"?(?P<audit_key>[A-Za-z0-9_./:-]+)\\\"?(?: |$)"
    }

    stage.labels {
      values = {
        audit_type = "",
        audit_key  = "",
      }
    }
  }

  loki.process "audit_fs" {
    forward_to = [loki.write.local.receiver]

    stage.json {
      expressions = {
        event_time = "",
        kind       = "",
        scope      = "",
        success    = "",
      }
    }

    stage.drop {
      source = "kind"
      expression = "audit_fs_summary"
      drop_counter_reason = "drop_audit_fs_summary_from_raw_stream"
    }

    stage.timestamp {
      source            = "event_time"
      format            = "RFC3339"
      action_on_failure = "skip"
    }

    stage.labels {
      values = {
        scope   = "",
        success = "",
      }
    }
  }

  loki.process "audit_fs_summary" {
    forward_to = [loki.write.local.receiver]

    stage.json {
      expressions = {
        event_time   = "",
        summary_kind = "",
        scope        = "",
      }
    }

    stage.timestamp {
      source            = "event_time"
      format            = "RFC3339"
      action_on_failure = "skip"
    }

    stage.labels {
      values = {
        summary_kind = "",
        scope        = "",
      }
    }
  }

  loki.process "audit_exec" {
    forward_to = [loki.write.local.receiver]

    stage.json {
      expressions = {
        event_time = "",
        kind       = "",
        success    = "",
      }
    }

    stage.drop {
      source = "kind"
      expression = "audit_exec_summary"
      drop_counter_reason = "drop_audit_exec_summary_from_raw_stream"
    }

    stage.timestamp {
      source            = "event_time"
      format            = "RFC3339"
      action_on_failure = "skip"
    }

    stage.labels {
      values = {
        success = "",
      }
    }
  }

  loki.process "audit_exec_summary" {
    forward_to = [loki.write.local.receiver]

    stage.json {
      expressions = {
        event_time   = "",
        summary_kind = "",
      }
    }

    stage.timestamp {
      source            = "event_time"
      format            = "RFC3339"
      action_on_failure = "skip"
    }

    stage.labels {
      values = {
        summary_kind = "",
      }
    }
  }

  loki.process "audit_net" {
    forward_to = [loki.write.local.receiver]

    stage.json {
      expressions = {
        event_time   = "",
        kind         = "",
        success      = "",
        family       = "",
        country_code = "",
      }
    }

    stage.drop {
      source = "kind"
      expression = "audit_net_summary"
      drop_counter_reason = "drop_audit_net_summary_from_raw_stream"
    }

    stage.timestamp {
      source            = "event_time"
      format            = "RFC3339"
      action_on_failure = "skip"
    }

    stage.labels {
      values = {
        success      = "",
        family       = "",
        country_code = "",
      }
    }
  }

  loki.process "audit_net_summary" {
    forward_to = [loki.write.local.receiver]

    stage.json {
      expressions = {
        event_time   = "",
        summary_kind = "",
        family       = "",
        country_code = "",
      }
    }

    stage.timestamp {
      source            = "event_time"
      format            = "RFC3339"
      action_on_failure = "skip"
    }

    stage.labels {
      values = {
        summary_kind = "",
        family       = "",
        country_code = "",
      }
    }
  }

  loki.process "net_usage" {
    forward_to = [loki.write.local.receiver]

    stage.json {
      expressions = {
        event_time  = "",
        time_bucket = "",
      }
    }

    stage.timestamp {
      source            = "event_time"
      format            = "RFC3339"
      action_on_failure = "skip"
    }

    stage.labels {
      values = {
        time_bucket = "",
      }
    }
  }

  loki.process "anomaly" {
    forward_to = [loki.write.local.receiver]

    stage.json {
      expressions = {
        event_time       = "",
        anomaly_type     = "",
        severity         = "",
        source_component = "",
      }
    }

    stage.timestamp {
      source            = "event_time"
      format            = "RFC3339"
      action_on_failure = "skip"
    }

    stage.labels {
      values = {
        anomaly_type     = "",
        severity         = "",
        source_component = "",
      }
    }
  }

  loki.process "journal" {
    forward_to = [loki.write.local.receiver]

    stage.drop {
      source = "unit,priority"
      separator = ";"
      expression = ${quote "${monitoringJournalUnitPattern};(debug|info|notice)"}
      drop_counter_reason = "drop_monitoring_routine_journal"
    }

    stage.match {
      selector = "{unit=\"loki.service\"} |~ \"(scheduler_processor|context canceled|error notifying.*EOF)\""
      action   = "drop"

      drop_counter_reason = "drop_loki_query_noise"
    }
  }

  loki.relabel "journal_labels" {
    forward_to = []

    rule {
      source_labels = ${renderStringList [ "__journal__systemd_unit" ]}
      target_label  = "unit"
    }

    rule {
      source_labels = ${renderStringList [ "__journal_priority_keyword" ]}
      target_label  = "priority"
    }
  }

  loki.source.journal "journal" {
    forward_to    = [loki.process.journal.receiver]
    relabel_rules = loki.relabel.journal_labels.rules
    labels        = ${renderMap journalLabels}
    max_age       = ${quote "${toString (cfg.retention.journalDays * 24)}h"}
  }

  loki.source.file "audit" {
    targets = [
      ${renderTarget "/var/log/audit/audit.log" auditLabels}
    ]
    forward_to    = [loki.process.audit.receiver]
    tail_from_end = false

    file_match {
      enabled     = true
      sync_period = "10s"
    }
  }

  ${lib.optionalString cfg.collectors.auditFs.enable ''
  loki.source.file "audit_fs" {
    targets = [
      ${renderTarget "/var/log/core-monitoring/audit-fs-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].ndjson" auditFsLabels}
    ]
    forward_to    = [loki.process.audit_fs.receiver]
    tail_from_end = false

    file_match {
      enabled     = true
      sync_period = "10s"
    }
  }

  loki.source.file "audit_fs_summary" {
    targets = [
      ${renderTarget "/var/log/core-monitoring/audit-fs-summary-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].ndjson" auditFsSummaryLabels}
    ]
    forward_to    = [loki.process.audit_fs_summary.receiver]
    tail_from_end = false

    file_match {
      enabled     = true
      sync_period = "10s"
    }
  }
  ''}

  ${lib.optionalString cfg.collectors.auditExec.enable ''
  loki.source.file "audit_exec" {
    targets = [
      ${renderTarget "/var/log/core-monitoring/audit-exec-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].ndjson" auditExecLabels}
    ]
    forward_to    = [loki.process.audit_exec.receiver]
    tail_from_end = false

    file_match {
      enabled     = true
      sync_period = "10s"
    }
  }

  loki.source.file "audit_exec_summary" {
    targets = [
      ${renderTarget "/var/log/core-monitoring/audit-exec-summary-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].ndjson" auditExecSummaryLabels}
    ]
    forward_to    = [loki.process.audit_exec_summary.receiver]
    tail_from_end = false

    file_match {
      enabled     = true
      sync_period = "10s"
    }
  }
  ''}

  ${lib.optionalString cfg.collectors.auditNet.enable ''
  loki.source.file "audit_net" {
    targets = [
      ${renderTarget "/var/log/core-monitoring/audit-net-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].ndjson" auditNetLabels}
    ]
    forward_to    = [loki.process.audit_net.receiver]
    tail_from_end = false

    file_match {
      enabled     = true
      sync_period = "10s"
    }
  }

  loki.source.file "audit_net_summary" {
    targets = [
      ${renderTarget "/var/log/core-monitoring/audit-net-summary-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].ndjson" auditNetSummaryLabels}
    ]
    forward_to    = [loki.process.audit_net_summary.receiver]
    tail_from_end = false

    file_match {
      enabled     = true
      sync_period = "10s"
    }
  }
  ''}

  ${lib.optionalString cfg.collectors.networkUsage.enable ''
  loki.source.file "net_usage" {
    targets = [
      ${renderTarget "/var/log/core-monitoring/network-usage-*.ndjson" netUsageLabels}
    ]
    forward_to    = [loki.process.net_usage.receiver]
    tail_from_end = false

    file_match {
      enabled     = true
      sync_period = "10s"
    }
  }
  ''}

  ${lib.optionalString hasNormalizedCollectors ''
  loki.source.file "anomaly" {
    targets = [
      ${renderTarget "/var/log/core-monitoring/anomaly-*.ndjson" anomalyLabels}
    ]
    forward_to    = [loki.process.anomaly.receiver]
    tail_from_end = false

    file_match {
      enabled     = true
      sync_period = "10s"
    }
  }
  ''}
''
