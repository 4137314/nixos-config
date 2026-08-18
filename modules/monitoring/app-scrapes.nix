/*
  monitoring/app-scrapes.nix — Prometheus scrape jobs for hub apps that
  expose /metrics.

  Prerequisites in the apps
  -------------------------
  Nextcloud    — install "Prometheus Metrics Exporter" app + set
                 `settings.metrics.token`; token in env for scrape auth.
  Vikunja      — `settings.metrics.enabled = true` (set in hub/vikunja.nix).
  Miniflux     — `METRICS_COLLECTOR = "1"` (already set).
  Home Assistant — `prometheus:` in HA config (already set) +
                   long-lived access token in `/etc/prometheus/ha-token`
                   (`0400 prometheus prometheus`).
  Ollama       — exposes /metrics on the same port.
  ntfy         — `/metrics` when `enable_metrics = true` in settings.

  Every job is 15-30s scrape interval, all on 127.0.0.1.

  Provisioning the HA token (once):
    Home Assistant UI → Profile → Long-Lived Access Tokens → Create.
    Then:
      printf %s "<token>" | sudo install -m 0400 \
        -o prometheus -g prometheus /dev/stdin /etc/prometheus/ha-token

  Jobs for services declared elsewhere but currently disabled
  ----------------------------------------------------------
  Suricata (`modules/security/suricata.nix`) is commented out in
  configuration.nix, so its scrape job is NOT declared here. Re-enable
  the module first, then add the scrape block back.
*/
_: {
  services.prometheus.scrapeConfigs = [
    {
      job_name = "vikunja";
      scrape_interval = "30s";
      static_configs = [ { targets = [ "127.0.0.1:3456" ]; } ];
      metrics_path = "/api/v1/metrics";
    }
    {
      job_name = "miniflux";
      scrape_interval = "60s";
      static_configs = [ { targets = [ "127.0.0.1:8081" ]; } ];
      metrics_path = "/metrics";
    }
    {
      job_name = "ollama";
      scrape_interval = "30s";
      static_configs = [ { targets = [ "127.0.0.1:11434" ]; } ];
      metrics_path = "/metrics";
    }
    {
      job_name = "home-assistant";
      scrape_interval = "30s";
      static_configs = [ { targets = [ "127.0.0.1:8123" ]; } ];
      metrics_path = "/api/prometheus";
      authorization = {
        type = "Bearer";
        credentials_file = "/etc/prometheus/ha-token";
      };
    }
    {
      job_name = "caddy";
      scrape_interval = "30s";
      static_configs = [ { targets = [ "127.0.0.1:2019" ]; } ];
      metrics_path = "/metrics";
    }
    {
      job_name = "qdrant";
      scrape_interval = "60s";
      static_configs = [ { targets = [ "127.0.0.1:6333" ]; } ];
      metrics_path = "/metrics";
    }
  ];

  systemd.tmpfiles.rules = [
    "d /etc/prometheus 0755 prometheus prometheus -"
  ];
}
