/*
  agents/observatory/metrics.nix — Prometheus counters for agent activity.

  Approach
  --------
  The `node_exporter` textfile collector scrapes `/var/lib/node_exporter/`
  every scrape interval. This module writes a `.prom` file there every
  5 min containing counters derived from the event bus:

    obs_events_total{agent="…", type="…"}      long-term counts
    obs_events_last_ts{agent="…"}              freshness watchdog
    obs_workflows_active                       distinct correlation_ids in last 24h
    obs_bus_size_bytes                         events.jsonl on-disk size

  Downstream: any Grafana panel or alert rule (see `monitoring/alerts.nix`)
  can query these series.

  The exporter path is configured to match
  `services.prometheus.exporters.node.enabledCollectors` — if the textfile
  collector isn't enabled elsewhere the file is still written but no
  Prometheus target picks it up (harmless).
*/
{ pkgs, ... }:
let
  inherit (import ./lib.nix { inherit pkgs; }) outputDir obs-event hardenedService;

  textfileDir = "/var/lib/node_exporter";
  bus = "${outputDir}/events.jsonl";

  obs-metrics = pkgs.writeShellApplication {
    name = "obs-metrics";
    runtimeInputs = with pkgs; [
      jq
      coreutils
      obs-event
    ];
    text = ''
      set -uo pipefail
      out=${textfileDir}/observatory.prom.tmp
      final=${textfileDir}/observatory.prom
      mkdir -p ${textfileDir}

      {
        echo "# HELP obs_events_total Number of observatory events by agent + type."
        echo "# TYPE obs_events_total counter"
        if [ -f "${bus}" ]; then
          jq -r 'group_by([.agent,.type])
                 | map({agent:.[0].agent, type:.[0].type, n:length})
                 | .[]
                 | "obs_events_total{agent=\"\(.agent)\",type=\"\(.type)\"} \(.n)"' \
             "${bus}"
        fi

        echo "# HELP obs_events_last_ts Unix epoch of last event from agent."
        echo "# TYPE obs_events_last_ts gauge"
        if [ -f "${bus}" ]; then
          jq -r 'group_by(.agent)
                 | map({agent:.[0].agent, ts:(max_by(.ts).ts)})
                 | .[]
                 | "obs_events_last_ts{agent=\"\(.agent)\"} \((.ts | sub("Z$";"+00:00") | fromdateiso8601))"' \
             "${bus}"
        fi

        cutoff=$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ)
        active=$(obs-event query --since="$cutoff" --limit=10000 2>/dev/null \
                 | jq -s '[.[] | .correlation_id // .id] | unique | length')
        echo "# HELP obs_workflows_active Distinct correlation_ids in the last 24h."
        echo "# TYPE obs_workflows_active gauge"
        echo "obs_workflows_active ''${active:-0}"

        size=$(stat -c%s "${bus}" 2>/dev/null || echo 0)
        echo "# HELP obs_bus_size_bytes On-disk size of events.jsonl."
        echo "# TYPE obs_bus_size_bytes gauge"
        echo "obs_bus_size_bytes $size"
      } > "$out"

      # Atomic swap — node_exporter never sees a half-written file.
      mv "$out" "$final"
    '';
  };
in
{
  environment.systemPackages = [ obs-metrics ];

  systemd = {
    tmpfiles.rules = [
      "d ${textfileDir} 0755 root root -"
    ];

    services.obs-metrics = {
      description = "Observatory — export bus counters to node_exporter textfile";
      serviceConfig = hardenedService // {
        ExecStart = "${obs-metrics}/bin/obs-metrics";
        ReadWritePaths = [
          outputDir
          textfileDir
        ];
      };
    };

    timers.obs-metrics = {
      description = "Observatory metrics — every 5 min";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/5";
        Persistent = false;
        RandomizedDelaySec = "30s";
      };
    };
  };
}
