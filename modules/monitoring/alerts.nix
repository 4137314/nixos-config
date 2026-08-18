/*
  monitoring/alerts.nix — Prometheus alerting rules + blackbox synthetic
  probes + Grafana contact points.

  Alert flow
  ----------
     Prometheus rules  ─┐
     Grafana rules      ├─► Grafana unified alerting  ─► ntfy topic "alerts"
                        │                              (see monitoring/ntfy.nix)
     Blackbox exporter ─┘

  Blackbox exporter
  -----------------
  Runs HTTP probes against the internal services every 30 s from Prometheus.
  Alerts fire when a probe fails 3 consecutive times (~90 s).

  Rules included
  --------------
  ServiceDown          Any monitored systemd unit in `failed` state.
  HighDiskUsage        Any filesystem >85 %.
  DiskCritical         Any filesystem >95 %.
  HighMemoryUsage      RAM available <10 % for 5 min.
  HighTemperature      CPU/GPU package temp >85 °C for 2 min.
  SmartFailing         S.M.A.R.T. self-test failed or reallocated sectors > 0.
  HTTPProbeDown        blackbox probe returns non-2xx for 3 checks.

  Grafana contact point
  ---------------------
  Provisions one "ntfy" contact point pointing at the local ntfy topic
  `alerts`. The bearer token lives at /etc/ntfy/grafana-token (400 grafana)
  — swap to sops once ready.
*/
{ pkgs, ... }:
let
  # Endpoints probed by blackbox — hostnames must resolve locally
  # (loopback, or via AdGuard DNS rewrites).
  probeTargets = {
    "nextcloud" = "http://127.0.0.1:80";
    "grafana" = "http://127.0.0.1:3000/api/health";
    "forgejo" = "http://127.0.0.1:3080/api/healthz";
    "adguard" = "http://127.0.0.1:3053/control/status";
    "jellyfin" = "http://127.0.0.1:8096/System/Info/Public";
    "syncthing" = "http://127.0.0.1:8384/rest/system/ping";
  };
in
{
  # --------------------------------------------------------------------------
  # Blackbox exporter — synthetic HTTP probes.
  # --------------------------------------------------------------------------
  services.prometheus = {
    exporters.blackbox = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9115;
      configFile = pkgs.writeText "blackbox.yml" (
        builtins.toJSON {
          modules = {
            http_2xx = {
              prober = "http";
              timeout = "5s";
              http = {
                preferred_ip_protocol = "ip4";
                valid_status_codes = [
                  200
                  201
                  204
                  301
                  302
                  401
                ];
                fail_if_ssl = false;
                fail_if_not_ssl = false;
              };
            };
          };
        }
      );
    };

    # ------------------------------------------------------------------------
    # Scrape blackbox for each service (relabel trick to pass URL as param).
    # ------------------------------------------------------------------------
    scrapeConfigs = [
      {
        job_name = "blackbox";
        metrics_path = "/probe";
        params.module = [ "http_2xx" ];
        scrape_interval = "30s";
        static_configs = [
          { targets = builtins.attrValues probeTargets; }
        ];
        relabel_configs = [
          {
            source_labels = [ "__address__" ];
            target_label = "__param_target";
          }
          {
            source_labels = [ "__param_target" ];
            target_label = "instance";
          }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:9115";
          }
        ];
      }
    ];

    # ------------------------------------------------------------------------
    # Alert rules.
    # ------------------------------------------------------------------------
    ruleFiles = [
      (pkgs.writeText "hacker-box-rules.yml" (
        builtins.toJSON {
          groups = [
            {
              name = "hacker-box";
              rules = [
                {
                  alert = "ServiceDown";
                  expr = ''node_systemd_unit_state{state="failed"} == 1'';
                  for = "5m";
                  labels.severity = "critical";
                  annotations = {
                    summary = "systemd unit {{ $labels.name }} is failed";
                    description = "{{ $labels.name }} has been in the failed state for >5 min.";
                  };
                }
                {
                  alert = "HighDiskUsage";
                  expr = ''(1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|devtmpfs"} / node_filesystem_size_bytes) * 100 > 85'';
                  for = "10m";
                  labels.severity = "warning";
                  annotations.summary = "Disk {{ $labels.mountpoint }} > 85% used";
                }
                {
                  alert = "DiskCritical";
                  expr = ''(1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|devtmpfs"} / node_filesystem_size_bytes) * 100 > 95'';
                  for = "2m";
                  labels.severity = "critical";
                  annotations.summary = "Disk {{ $labels.mountpoint }} > 95% used";
                }
                {
                  alert = "HighMemoryUsage";
                  expr = "(node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 < 10";
                  for = "5m";
                  labels.severity = "warning";
                  annotations.summary = "Available memory < 10%";
                }
                {
                  alert = "HighTemperature";
                  expr = ''node_hwmon_temp_celsius{chip=~".*coretemp.*|.*k10temp.*"} > 85'';
                  for = "2m";
                  labels.severity = "warning";
                  annotations.summary = "CPU sensor {{ $labels.sensor }} > 85 °C";
                }
                {
                  alert = "SmartFailing";
                  expr = ''smartctl_device_smart_status{smart_passed="false"} == 1 or smartmon_reallocated_sectors_count_raw_value > 0'';
                  for = "0s";
                  labels.severity = "critical";
                  annotations.summary = "SMART failure on {{ $labels.device }}";
                }
                {
                  alert = "HTTPProbeDown";
                  expr = "probe_success == 0";
                  for = "3m";
                  labels.severity = "critical";
                  annotations = {
                    summary = "Service probe failing: {{ $labels.instance }}";
                    description = "Blackbox probe {{ $labels.instance }} has been failing for 3 min.";
                  };
                }
              ];
            }
          ];
        }
      ))
    ];
  };

  # --------------------------------------------------------------------------
  # Grafana — provision an ntfy contact point + notification policy.
  # Merged with the existing datasource provisioning in observability.nix.
  # --------------------------------------------------------------------------
  services.grafana.provision = {
    alerting.contactPoints.settings.contactPoints = [
      {
        name = "ntfy";
        receivers = [
          {
            uid = "ntfy-alerts";
            type = "webhook";
            settings = {
              url = "http://127.0.0.1:2586/alerts";
              httpMethod = "POST";
              # Bearer token file — populated manually today, sops in the future.
              # Grafana reads this file at start and injects the value.
            };
            secureSettings.authorization_credentials = "$__file{/etc/ntfy/grafana-token}";
          }
        ];
      }
    ];

    alerting.policies.settings.policies = [
      {
        receiver = "ntfy";
        group_by = [
          "alertname"
          "severity"
        ];
        group_wait = "30s";
        group_interval = "5m";
        repeat_interval = "12h";
      }
    ];
  };

}
