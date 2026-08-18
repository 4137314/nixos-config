/*
  agents/observatory/active.nix — Active agents (healer, janitor, brain).

  Complements passive.nix with agents that ACT on low-risk operational
  tasks, and the meta-agent that closes feedback loops.

  Causal chain example
  --------------------
    07:00  obs-doctor    → publish failed_units       (id=D, corr=CORR)
    07:10  obs-healer    ← reads D, restart allowed unit
                        → publish heal_attempted     (id=H, corr=CORR,
                                                       cause=D)
    22:00  obs-brain     → reads events since 24h ago, groups by CORR,
                          summarises "doctor found X, healer fixed X."
*/
{ pkgs, ... }:
let
  inherit (import ./lib.nix { inherit pkgs; })
    outputDir
    obs-ask
    obs-ntfy
    obs-event
    hardenedService
    ;

  stateDir = "${outputDir}/state";
  healerDir = "${stateDir}/healer-cooldown";

  reasonModel = "qwen2.5:7b";

  # --------------------------------------------------------------------------
  # Healer allowlist — units the healer is permitted to restart.
  # Kept in a plain text file (one glob per line) so it's easily
  # auditable and can be extended without touching Nix.
  # --------------------------------------------------------------------------
  healerAllowlist = pkgs.writeText "healer-allowlist" ''
    podman-perplexica.service
    podman-flowise.service
    podman-searxng.service
    podman-qdrant.service
    podman-piper-tts.service
    podman-glance.service
    podman-it-tools.service
    podman-cyberchef.service
    podman-rss-bridge.service
    podman-silverbullet.service
    podman-kiwix.service
    podman-archivebox.service
    podman-actual-budget.service
    podman-memos.service
    podman-changedetection.service
    podman-karakeep.service
    podman-n8n.service
    ntfy-sh.service
    promtail.service
    vaultwarden.service
    vikunja.service
    audiobookshelf.service
    miniflux.service
    immich-server.service
    syncthing.service
    obs-doctor.service
    obs-analyst.service
    obs-triage.service
    obs-diary.service
    obs-indexer.service
    obs-brain.service
  '';

  # --------------------------------------------------------------------------
  # obs-healer — subscribes to `failed_units` events, restarts each unit
  # if it is on the allowlist and has not exceeded its cooldown.
  # --------------------------------------------------------------------------
  obs-healer = pkgs.writeShellApplication {
    name = "obs-healer";
    runtimeInputs = with pkgs; [
      jq
      systemd
      coreutils
      util-linux
      obs-event
      obs-ntfy
    ];
    text = ''
      set -uo pipefail
      allowlist=$(cat ${healerAllowlist})
      mkdir -p ${healerDir}

      # Consume the LAST failed_units event within the last 30 minutes.
      cutoff=$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
      event=$(obs-event query --type=failed_units --since="$cutoff" --limit=1 \
              | tail -1 || true)
      [ -z "$event" ] && exit 0

      parent_id=$(echo "$event" | jq -r '.id')
      parent_corr=$(echo "$event" | jq -r '.correlation_id // .id')
      units=$(echo "$event" | jq -r '.payload.units[]?' || true)
      [ -z "$units" ] && exit 0

      results=()
      for unit in $units; do
        if ! grep -Fxq "$unit" <<< "$allowlist"; then
          results+=("$(jq -cn --arg u "$unit" \
                        '{unit:$u, action:"skip", reason:"not-in-allowlist"}')")
          continue
        fi

        cd_file="${healerDir}/$unit.jsonl"
        recent=0
        cutoff24=$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ)
        if [ -f "$cd_file" ]; then
          recent=$(jq -c --arg c "$cutoff24" 'select(.ts >= $c)' "$cd_file" | wc -l)
        fi
        if [ "$recent" -ge 3 ]; then
          results+=("$(jq -cn --arg u "$unit" \
                        '{unit:$u, action:"escalate", reason:"cooldown-3-per-24h"}')")
          continue
        fi

        if systemctl reset-failed "$unit" 2>/dev/null \
           && systemctl restart "$unit" 2>/dev/null; then
          outcome=success
        else
          outcome=failure
        fi

        ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        entry=$(jq -cn --arg ts "$ts" --arg r "$outcome" '{ts:$ts, result:$r}')
        ( flock -x 9; echo "$entry" >> "$cd_file" ) 9>>"$cd_file.lock"

        results+=("$(jq -cn --arg u "$unit" --arg r "$outcome" \
                      '{unit:$u, action:"restart", result:$r}')")
      done

      payload=$(printf '%s\n' "''${results[@]}" | jq -cs '{actions:.}')
      # Publish with --cause pointing at the doctor's event ID, and inherit
      # the correlation_id so the whole workflow shows up in `obs-event chain`.
      obs-event publish obs-healer heal_attempted "$payload" \
        --cause="$parent_id" --correlation="$parent_corr" >/dev/null || true

      if echo "$payload" | jq -e '.actions[] | select(.action=="escalate")' >/dev/null; then
        obs-ntfy "Healer cooldown hit" high "warning,rotating_light" \
          "$(echo "$payload" | jq -r '.actions[] | select(.action=="escalate") | "escalate: \(.unit)"')"
      fi
    '';
  };

  # --------------------------------------------------------------------------
  # obs-janitor — daily safe cleanups.
  # --------------------------------------------------------------------------
  obs-janitor = pkgs.writeShellApplication {
    name = "obs-janitor";
    runtimeInputs = with pkgs; [
      nix
      podman
      systemd
      findutils
      coreutils
      jq
      gawk
      obs-event
    ];
    text = ''
      set -uo pipefail
      today=$(date +%Y-%m-%d)
      dir="${outputDir}/janitor/$today"
      mkdir -p "$dir"
      report="$dir/report.md"
      corr="janitor-$(date -u +%Y%m%dT%H%M%SZ)"

      before_disk=$(df -B1 --output=avail / | tail -1)

      {
        echo "# obs-janitor — $today"; echo
        echo '## nix-collect-garbage (>30 days)'; echo '```'
        nix-collect-garbage --delete-older-than 30d 2>&1 | tail -20 || true
        echo '```'; echo
        echo '## podman system prune -f'; echo '```'
        podman system prune -f 2>&1 | tail -20 || true
        echo '```'; echo
        echo '## /tmp files older than 7 days'
        find /tmp -type f -mtime +7 -print -delete 2>/dev/null | wc -l \
          | awk '{print $1 " files removed"}' || true
        echo
        echo '## journalctl --vacuum-time=90d'; echo '```'
        journalctl --vacuum-time=90d 2>&1 | tail -5 || true
        echo '```'
      } > "$report"

      after_disk=$(df -B1 --output=avail / | tail -1)
      reclaimed=$((after_disk - before_disk))
      echo "Reclaimed: $reclaimed bytes" >> "$report"

      obs-event publish obs-janitor cleanup_done \
        "$(jq -cn --argjson r "$reclaimed" --arg p "$report" '{reclaimed:$r, report:$p}')" \
        --correlation="$corr" >/dev/null || true
    '';
  };

  # --------------------------------------------------------------------------
  # obs-brain — meta-agent. Uses the enriched bus schema (correlation +
  # cause) so it can present cohesive workflow narratives instead of
  # isolated events.
  # --------------------------------------------------------------------------
  obs-brain = pkgs.writeShellApplication {
    name = "obs-brain";
    runtimeInputs = with pkgs; [
      jq
      coreutils
      obs-ask
      obs-ntfy
      obs-event
    ];
    text = ''
      set -uo pipefail
      today=$(date +%Y-%m-%d)
      dir="${outputDir}/brain/$today"
      mkdir -p "$dir"
      report="$dir/report.md"
      corr="brain-$(date -u +%Y%m%dT%H%M%SZ)"

      cutoff=$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ)
      events=$(obs-event query --since="$cutoff" --limit=1000 2>/dev/null || true)
      if [ -z "$events" ]; then
        echo "brain: no events in 24h" > "$report"
        exit 0
      fi

      # Aggregate topics + counts.
      summary=$(echo "$events" | jq -c 'group_by(.type) | map({type:.[0].type, count:length}) | sort_by(-.count)')

      # Group events by correlation_id → build workflow narratives.
      workflows=$(echo "$events" | jq -c '
        group_by(.correlation_id // .id)
        | map({
            correlation: .[0].correlation_id // .[0].id,
            steps: map({agent, type, ts})
          })
        | map(select(.steps | length > 1))
      ')

      # RAG side context (best-effort — obs-rag may be down).
      rag_context=""
      for topic in $(echo "$summary" | jq -r '.[].type' | head -5); do
        rag_context+="── RAG for topic: $topic ──"$'\n'
        rag_context+=$(obs-rag query "$topic" 3 2>/dev/null || echo "(rag unavailable)")$'\n\n'
      done

      {
        echo "# obs-brain — $today"; echo
        echo '## Event topics in last 24h'; echo '```json'
        echo "$summary" | jq .
        echo '```'; echo
        echo '## Multi-step workflows (grouped by correlation_id)'; echo '```json'
        echo "$workflows" | jq .
        echo '```'; echo
        echo '## RAG context'; echo '```'
        echo "$rag_context"
        echo '```'
      } > "$report"

      reflection=$(
        obs-ask "${reasonModel}" \
          "Sei il meta-agente di una workstation NixOS. Ricevi: (a) conteggi eventi per topic nelle ultime 24h, (b) workflow multi-step raggruppati per correlation_id (mostrano CHI ha causato CHE), (c) contesto RAG estratto da config/log/report. Produci in italiano: 1) un paragrafo breve sullo stato macchina, 2) fino a 3 preoccupazioni concrete che LEGANO più eventi tra loro (usa i workflow), 3) un 'prossimo passo' concreto. Terso." \
          < "$report"
      )
      { echo; echo '---'; echo '## Reflection'; echo; echo "$reflection"; } >> "$report"

      obs-ntfy "Brain — $today" default "brain,link" \
        "$(echo "$reflection" | head -c 800)"

      obs-event publish obs-brain daily_meta \
        "$(jq -cn --arg r "$report" --arg t "$reflection" '{report:$r, text:$t}')" \
        --correlation="$corr" >/dev/null || true
    '';
  };
in
{
  environment.systemPackages = [
    obs-healer
    obs-janitor
    obs-brain
  ];

  systemd = {
    tmpfiles.rules = [
      "d ${stateDir}   0755 root root -"
      "d ${healerDir}  0755 root root -"
      "d ${outputDir}/janitor  0755 root users -"
      "d ${outputDir}/brain    0755 root users -"
    ];

    services = {
      obs-healer = {
        description = "Observatory — auto-restart failed units (allowlisted)";
        after = [ "obs-doctor.service" ];
        serviceConfig = hardenedService // {
          ExecStart = "${obs-healer}/bin/obs-healer";
          # `systemctl restart` needs to write to /dev/kmsg, etc.
          MemoryDenyWriteExecute = false;
        };
      };
      obs-janitor = {
        description = "Observatory — safe cleanups (GC, prune, tmp, journal)";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = hardenedService // {
          ExecStart = "${obs-janitor}/bin/obs-janitor";
          ReadWritePaths = [
            outputDir
            "/nix/var"
            "/tmp"
            "/var/log/journal"
          ];
          MemoryDenyWriteExecute = false;
        };
      };
      obs-brain = {
        description = "Observatory — meta-agent (RAG + bus → narrative)";
        after = [
          "network-online.target"
          "obs-doctor.service"
          "obs-triage.service"
        ];
        wants = [ "network-online.target" ];
        serviceConfig = hardenedService // {
          ExecStart = "${obs-brain}/bin/obs-brain";
        };
      };
    };

    timers = {
      obs-healer = {
        description = "Observatory healer — every 10 min";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*:0/10";
          Persistent = false;
          RandomizedDelaySec = "1m";
        };
      };
      obs-janitor = {
        description = "Observatory janitor — daily 04:30";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 04:30:00";
          Persistent = true;
          RandomizedDelaySec = "20m";
        };
      };
      obs-brain = {
        description = "Observatory brain — daily 22:00";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 22:00:00";
          Persistent = true;
          RandomizedDelaySec = "10m";
        };
      };
    };
  };
}
