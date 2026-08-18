/*
  monitoring/observability.nix — Prometheus + Grafana observability stack.

  Architecture
  ------------
  Prometheus scrapes four local exporters every 15 seconds:

    node_exporter    :9100   CPU, RAM, filesystem, network, temps (hwmon)
    smartctl         :9633   S.M.A.R.T. disk health and wear
    systemd          :9558   Systemd unit states (shows failed services)
    process          :9256   Per-process CPU/RAM (Jellyfin, qBittorrent, etc.)

  Grafana serves dashboards at http://nixos-hacker-box:3000.
  Prometheus listens only on 127.0.0.1 (Grafana is on the same host).

  *** ACTION REQUIRED:
      Set the Grafana admin password BEFORE running nixos-rebuild switch:
        echo -n "YourGrafanaPassword" | sudo tee /etc/grafana-admin-pass
        sudo chmod 600 /etc/grafana-admin-pass

      Adjust `smartctl.devices` to match your disk device names:
        ls /dev/sd* /dev/nvme*  →  update the list below.        ***

  Grafana dashboard IDs to import (Dashboards → + Import → paste ID):
    1860   Node Exporter Full (comprehensive system overview)
    14928  Node Exporter for Prometheus (RAM/CPU detail)
    10664  Systemd service status
    3992   SMART Disk Monitoring

  Alerting (optional next step)
  ------------------------------
  Add Grafana contact points (Alerting → Contact points) for email or
  Telegram notifications on disk health degradation, high CPU temp, etc.
*/
_:
let
  prometheusPort = 9090;
  grafanaPort = 3000;
in
{
  # ---------------------------------------------------------------------------
  # Prometheus
  # ---------------------------------------------------------------------------

  services.prometheus = {
    enable = true;
    port = prometheusPort;
    listenAddress = "127.0.0.1"; # Grafana is local; no external access needed.
    retentionTime = "30d";

    # `credentials_file` paths (e.g. /etc/prometheus/ha-token) are
    # provisioned out-of-band and don't exist at build time; the default
    # `checkConfig = true` would stat them and fail the rebuild.
    # `syntax-only` still catches YAML / label / regex errors.
    checkConfig = "syntax-only";

    # --- Exporters -----------------------------------------------------------

    exporters = {
      node = {
        enable = true;
        port = 9100;
        openFirewall = false; # Local only.
        enabledCollectors = [
          "cpu"
          "cpufreq"
          "diskstats"
          "filesystem"
          "hwmon" # CPU/GPU/disk temperatures
          "interrupts"
          "loadavg"
          "meminfo"
          "netdev"
          "processes"
          "systemd"
          "thermal_zone"
          "time"
        ];
      };

      smartctl = {
        enable = true;
        port = 9633;
        openFirewall = false;
        # sda = NAS (Btrfs), nvme0n1 = system disk.
        devices = [
          "/dev/sda"
          "/dev/nvme0n1"
        ];
      };

      systemd = {
        enable = true;
        port = 9558;
        openFirewall = false;
      };

      process = {
        enable = true;
        port = 9256;
        openFirewall = false;
        settings.process_names = [
          {
            name = "jellyfin";
            cmdline = [ "jellyfin" ];
          }
          {
            name = "qbittorrent";
            cmdline = [ "qbittorrent-nox" ];
          }
          {
            name = "sonarr";
            cmdline = [ "Sonarr" ];
          }
          {
            name = "radarr";
            cmdline = [ "Radarr" ];
          }
          {
            name = "nextcloud-php";
            cmdline = [ "php-fpm" ];
          }
          {
            name = "prometheus";
            cmdline = [ "prometheus" ];
          }
          {
            name = "grafana";
            cmdline = [ "grafana" ];
          }
        ];
      };
    };

    # --- Scrape configs ------------------------------------------------------

    scrapeConfigs = [
      {
        job_name = "node";
        scrape_interval = "15s";
        static_configs = [ { targets = [ "127.0.0.1:9100" ]; } ];
      }
      {
        job_name = "smartctl";
        scrape_interval = "60s"; # S.M.A.R.T. polling is slow by design.
        static_configs = [ { targets = [ "127.0.0.1:9633" ]; } ];
      }
      {
        job_name = "systemd";
        scrape_interval = "30s";
        static_configs = [ { targets = [ "127.0.0.1:9558" ]; } ];
      }
      {
        job_name = "process";
        scrape_interval = "15s";
        static_configs = [ { targets = [ "127.0.0.1:9256" ]; } ];
      }
    ];
  };

  # ---------------------------------------------------------------------------
  # Grafana
  # ---------------------------------------------------------------------------

  services.grafana = {
    enable = true;

    settings = {
      server = {
        # Loopback only — Caddy terminates TLS at https://grafana.nixos-hacker-box.
        http_addr = "127.0.0.1";
        http_port = grafanaPort;
        domain = "grafana.nixos-hacker-box";
        root_url = "https://grafana.nixos-hacker-box/";
      };

      security = {
        admin_user = "admin";
        # Password read from file at startup — never stored in Nix store.
        admin_password = "$__file{/etc/grafana-admin-pass}";
      };

      # Disable telemetry.
      analytics.reporting_enabled = false;
    };

    # Automatically provision the Prometheus datasource so dashboards work
    # immediately after the first switch — no manual UI configuration needed.
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://127.0.0.1:${toString prometheusPort}";
          isDefault = true;
        }
      ];
    };
  };

  # No firewall opening — Grafana is only reachable via the Caddy vhost.

  # Ensure /etc/grafana-admin-pass is readable by the grafana user. The file
  # is manually created (root-owned, 0600) — this "z" rule adjusts perms
  # without touching content, so the secret never lands in the Nix store.
  systemd.tmpfiles.rules = [
    "z /etc/grafana-admin-pass 0640 root grafana - -"
  ];
}
