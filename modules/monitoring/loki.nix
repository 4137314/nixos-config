/*
  monitoring/loki.nix — Log aggregation with Loki + Promtail.

  Architecture
  ------------
     journald ──► Promtail (:9080)  ──►  Loki (:3100)  ──►  Grafana
                                                              (existing
                                                               Explore + logs
                                                               panel plugin)

  Everything is localhost-only. Loki storage is filesystem-based (BoltDB
  shipper) under /var/lib/loki — pointed at /srv/nas/loki once you want
  Btrfs snapshots to cover it. Default retention 30 days.

  Grafana datasource
  ------------------
  Auto-provisioned alongside Prometheus in modules/monitoring/observability.nix
  via `services.grafana.provision.datasources` — this module extends it.

  Query examples (LogQL)
  ----------------------
    {unit="sshd.service"}                              All SSH events.
    {unit="nginx.service"} |= "401"                    Nextcloud auth failures.
    {unit=~"jellyfin|nextcloud.*"} |= "error"          Cross-service errors.
    {unit="fail2ban.service"} |= "Ban"                 New bans.

  Retention & compaction
  ----------------------
  30 days rolling. Compactor runs hourly. Deletion is soft (marked for GC),
  reclaim next compaction cycle.
*/
{ config, ... }:
let
  lokiPort = 3100;
  promtailPort = 9080;
in
{
  services = {
    # ------------------------------------------------------------------------
    # Loki — log store and query engine.
    # ------------------------------------------------------------------------
    loki = {
      enable = true;
      configuration = {
        auth_enabled = false;

        server = {
          http_listen_address = "127.0.0.1";
          http_listen_port = lokiPort;
          grpc_listen_port = 9095;
        };

        common = {
          instance_addr = "127.0.0.1";
          path_prefix = "/var/lib/loki";
          storage.filesystem = {
            chunks_directory = "/var/lib/loki/chunks";
            rules_directory = "/var/lib/loki/rules";
          };
          replication_factor = 1;
          ring.kvstore.store = "inmemory";
        };

        schema_config.configs = [
          {
            from = "2024-01-01";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];

        limits_config = {
          retention_period = "720h"; # 30 days
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
        };

        compactor = {
          working_directory = "/var/lib/loki/compactor";
          retention_enabled = true;
          delete_request_store = "filesystem";
        };

        analytics.reporting_enabled = false;
      };
    };

    # ------------------------------------------------------------------------
    # Promtail — journald → Loki shipper.
    # ------------------------------------------------------------------------
    promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = promtailPort;
          grpc_listen_port = 0;
        };
        positions.filename = "/var/lib/promtail/positions.yaml";

        clients = [
          { url = "http://127.0.0.1:${toString lokiPort}/loki/api/v1/push"; }
        ];

        scrape_configs = [
          {
            job_name = "journal";
            journal = {
              max_age = "12h";
              labels = {
                job = "systemd-journal";
                host = config.networking.hostName;
              };
            };
            relabel_configs = [
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
              {
                source_labels = [ "__journal__hostname" ];
                target_label = "hostname";
              }
              {
                source_labels = [ "__journal_priority_keyword" ];
                target_label = "level";
              }
            ];
          }
        ];
      };
    };

    # ------------------------------------------------------------------------
    # Extra Grafana datasource — merged with the Prometheus one defined in
    # observability.nix via NixOS module merge semantics.
    # ------------------------------------------------------------------------
    grafana.provision.datasources.settings.datasources = [
      {
        name = "Loki";
        type = "loki";
        access = "proxy";
        url = "http://127.0.0.1:${toString lokiPort}";
        uid = "loki";
      }
    ];
  };

  # Promtail runs as a DynamicUser and can't create its own state directory
  # via `StateDirectory=`; pre-create it here so `positions.yaml` can be
  # written on first start.
  systemd.tmpfiles.rules = [
    "d /var/lib/promtail 0700 promtail promtail -"
  ];
}
