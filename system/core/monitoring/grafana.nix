{ config, lib, ... }:
let
  cfg = config.core.monitoring;
in lib.mkIf (cfg.enable && cfg.ui.enable) {
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = cfg.ports.grafana;
        domain = "127.0.0.1";
        root_url = "http://127.0.0.1:${toString cfg.ports.grafana}";
      };
      analytics = {
        reporting_enabled = false;
        check_for_updates = false;
      };
      security = {
        # nixos 26.05 requires an explicit grafana secret_key again.
        # keep it out of the nix store and generate a persistent per-host key on first start.
        secret_key = "$__file{/var/lib/grafana/secret_key}";
        cookie_samesite = "strict";
      };
      auth = {
        disable_login_form = false;
      };
      "auth.basic" = {
        enabled = true;
        password_policy = true;
      };
      log = {
        level = "warn";
      };
      "auth.anonymous" = {
        enabled = false;
      };
      users = {
        allow_sign_up = false;
        default_theme = "system";
      };
    };
    provision = {
      enable = true;
      datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            name = "Loki";
            type = "loki";
            access = "proxy";
            uid = "core-monitoring-loki";
            url = "http://127.0.0.1:${toString cfg.ports.loki}";
            editable = false;
            jsonData.maxLines = 1000;
          }
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            uid = "core-monitoring-prometheus";
            url = "http://127.0.0.1:${toString cfg.ports.prometheus}";
            editable = false;
          }
        ];
      };
      dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "core-monitoring";
            type = "file";
            folder = "Core Monitoring";
            disableDeletion = false;
            allowUiUpdates = false;
            editable = false;
            options.path = ./assets/dashboards;
          }
        ];
      };
    };
  };

  systemd.services.grafana.preStart = lib.mkAfter ''
    if [ ! -s /var/lib/grafana/secret_key ]; then
      umask 077
      head -c 32 /dev/urandom | base64 > /var/lib/grafana/secret_key
    fi
  '';
}
