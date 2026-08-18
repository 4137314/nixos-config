/*
  agents/observatory/passive.nix — Read-only agents.

  Four oneshots that collect data, ask the local LLM for a summary,
  write a Markdown report, and publish an event on the shared bus.
  Nothing on the system is modified.

  Correlation pattern
  -------------------
  Each script generates a per-run `corr` (correlation_id) at the top,
  and passes `--correlation=$corr` to every `obs-event publish` call
  it makes. Downstream active agents (`obs-healer`, `obs-brain`) can
  then set `--cause=<publish output id>` to thread the workflow.

    doctor run --correlation=doctor-<ts>
      └─ publish failed_units id=X
           └─ healer publish heal_attempted --cause=X --correlation=doctor-<ts>
                └─ brain reads chain via `obs-event chain X`
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

  # --------------------------------------------------------------------------
  # Agent 1 — self-doctor (daily 07:00)
  # --------------------------------------------------------------------------
  obs-doctor = pkgs.writeShellApplication {
    name = "obs-doctor";
    runtimeInputs = with pkgs; [
      systemd
      coreutils
      gnused
      jq
      obs-ask
      obs-ntfy
      obs-event
    ];
    text = ''
      set -uo pipefail
      today=$(date +%Y-%m-%d)
      dir="${outputDir}/doctor/$today"
      mkdir -p "$dir"
      report="$dir/report.md"
      corr="doctor-$(date -u +%Y%m%dT%H%M%SZ)"

      { echo "# self-doctor — $today"; echo; } > "$report"

      failed=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' || true)
      if [ -z "$failed" ]; then
        echo "No failed services." >> "$report"
        obs-event publish obs-doctor no_failed_units '{}' \
          --correlation="$corr" >/dev/null || true
        exit 0
      fi

      {
        echo "## Failed units"
        for u in $failed; do
          echo; echo "### $u"; echo '```'
          systemctl status "$u" --no-pager -l 2>/dev/null | tail -25 || true
          echo '```'
        done
      } >> "$report"

      diagnosis=$(
        obs-ask "qwen2.5:7b" \
          "You are a NixOS/systemd sysadmin. For each failed unit + status output produce one line: <unit>: one-sentence diagnosis + suggested fix command. Terse. English." \
          < "$report"
      )
      { echo; echo '---'; echo '## LLM diagnosis'; echo; echo "$diagnosis"; } >> "$report"

      count=$(echo "$failed" | wc -w)
      obs-ntfy "$count failed services" high "warning,stethoscope" \
        "$(echo "$diagnosis" | head -c 800)"

      payload=$(jq -cn \
        --argjson u "$(echo "$failed" | jq -R -s -c 'split("\n") | map(select(length>0))')" \
        --arg r "$report" \
        '{units:$u, report:$r}')
      obs-event publish obs-doctor failed_units "$payload" \
        --correlation="$corr" >/dev/null || true
    '';
  };

  # --------------------------------------------------------------------------
  # Agent 2 — self-analyst (Saturday 05:00)
  # --------------------------------------------------------------------------
  obs-analyst = pkgs.writeShellApplication {
    name = "obs-analyst";
    runtimeInputs = with pkgs; [
      statix
      deadnix
      git
      coreutils
      jq
      obs-ask
      obs-ntfy
      obs-event
    ];
    text = ''
      set -uo pipefail
      today=$(date +%Y-%m-%d)
      dir="${outputDir}/analyst/$today"
      mkdir -p "$dir"
      report="$dir/report.md"
      corr="analyst-$(date -u +%Y%m%dT%H%M%SZ)"

      {
        echo "# self-analyst — $today"; echo
        echo '## statix'; echo '```'
        statix check /etc/nixos 2>&1 | head -100 || true
        echo '```'; echo
        echo '## deadnix'; echo '```'
        deadnix -f /etc/nixos 2>&1 | head -100 || true
        echo '```'; echo
        echo '## git activity (last 7 days)'; echo '```'
        git -C /etc/nixos log --since='7 days ago' --stat \
          --pretty=format:'%h %ai %s' 2>&1 | head -200 || true
        echo '```'
      } > "$report"

      summary=$(
        obs-ask "qwen2.5:7b" \
          "You are analysing a personal NixOS flake. Produce a 5-bullet weekly summary: what changed this week (from git), lint status (statix/deadnix), and what deserves attention next. Terse. English." \
          < "$report"
      )
      { echo; echo '---'; echo '## LLM summary'; echo; echo "$summary"; } >> "$report"

      obs-ntfy "Weekly analyst" default "clipboard,brain" \
        "$(echo "$summary" | head -c 800)"

      obs-event publish obs-analyst weekly_summary \
        "$(jq -cn --arg r "$report" --arg s "$summary" '{report:$r, summary:$s}')" \
        --correlation="$corr" >/dev/null || true
    '';
  };

  # --------------------------------------------------------------------------
  # Agent 3 — log-triage (every 4h)
  # --------------------------------------------------------------------------
  obs-triage = pkgs.writeShellApplication {
    name = "obs-triage";
    runtimeInputs = with pkgs; [
      systemd
      coreutils
      jq
      obs-ask
      obs-ntfy
      obs-event
    ];
    text = ''
      set -uo pipefail
      stamp=$(date +%Y-%m-%d-%H)
      dir="${outputDir}/triage/$(date +%Y-%m-%d)"
      mkdir -p "$dir"
      report="$dir/$(date +%H).md"
      corr="triage-$(date -u +%Y%m%dT%H%M%SZ)"

      logs=$(journalctl --since='4 hours ago' -p warning --no-pager -q \
             2>/dev/null | head -400)
      if [ -z "$logs" ]; then
        echo "OK — no warnings in the last 4h ($stamp)" > "$report"
        obs-event publish obs-triage log_clean '{}' \
          --correlation="$corr" >/dev/null || true
        exit 0
      fi

      {
        echo "# log-triage — $stamp"; echo
        echo '## Raw window (last 4h, priority ≥ warning, head 400)'
        echo '```'; echo "$logs"; echo '```'
      } > "$report"

      triage=$(
        obs-ask "llama3.2:3b" \
          "You are a log analyst. Given the last 4h of journald warnings+errors, either return exactly 'OK' if it is all routine noise (healthchecks, DHCP renewals, expected restarts), OR list up to 3 real concerns in one sentence each. Nothing else." \
          <<< "$logs"
      )
      { echo; echo '---'; echo '## LLM triage'; echo; echo "$triage"; } >> "$report"

      if [ "$(printf '%s' "$triage" | tr -d '[:space:]')" != "OK" ]; then
        obs-ntfy "Log anomalies" default "mag,warning" \
          "$(echo "$triage" | head -c 800)"
        obs-event publish obs-triage log_anomaly \
          "$(jq -cn --arg t "$triage" --arg r "$report" '{triage:$t, report:$r}')" \
          --correlation="$corr" >/dev/null || true
      else
        obs-event publish obs-triage log_clean '{}' \
          --correlation="$corr" >/dev/null || true
      fi
    '';
  };

  # --------------------------------------------------------------------------
  # Agent 4 — diary (daily 23:00)
  # --------------------------------------------------------------------------
  obs-diary = pkgs.writeShellApplication {
    name = "obs-diary";
    runtimeInputs = with pkgs; [
      git
      findutils
      coreutils
      jq
      obs-ask
      obs-ntfy
      obs-event
    ];
    text = ''
      set -uo pipefail
      today=$(date +%Y-%m-%d)
      dir="${outputDir}/diary"
      mkdir -p "$dir"
      report="$dir/$today.md"
      corr="diary-$(date -u +%Y%m%dT%H%M%SZ)"

      {
        echo "# Diary — $(date '+%A, %d %B %Y')"; echo
        echo '## Git commits (last 24h, all repos under /home/main)'
        find /home/main -maxdepth 5 -type d -name .git 2>/dev/null \
        | while read -r gitdir; do
            repo="$(dirname "$gitdir")"
            author=$(git -C "$repo" config user.email 2>/dev/null || echo "")
            commits=$(git -C "$repo" log --since='24 hours ago' \
                        ''${author:+--author="$author"} \
                        --pretty=format:'- %h %s [%ar]' 2>/dev/null || true)
            if [ -n "$commits" ]; then
              echo; echo "### $(basename "$repo")"; echo "$commits"
            fi
          done
        echo
        echo '## Files touched (last 24h, /home/main, filtered)'
        find /home/main -type f -mtime -1 \
          -not -path '*/.cache/*' -not -path '*/.local/share/Trash/*' \
          -not -path '*/node_modules/*' -not -path '*/.git/*' \
          -not -path '*/Downloads/*' -not -path '*/.mozilla/*' \
          -not -path '*/.config/Code/*' -not -path '*/.direnv/*' \
          2>/dev/null | head -30
      } > "$report"

      reflection=$(
        obs-ask "qwen2.5:7b" \
          "Sei il diario personale dell'utente. Dati i commit git e i file modificati oggi, scrivi una riflessione in prima persona (paragrafo unico, 3-5 frasi, tono personale, italiano) su cosa ha fatto. Niente elenchi, niente markdown." \
          < "$report"
      )
      { echo; echo '---'; echo '## Reflection'; echo; echo "$reflection"; } >> "$report"

      obs-ntfy "Diary — $(date +%d/%m)" min "bookmark_tabs" \
        "$(echo "$reflection" | head -c 800)"

      obs-event publish obs-diary daily_reflection \
        "$(jq -cn --arg r "$report" --arg t "$reflection" '{report:$r, text:$t}')" \
        --correlation="$corr" >/dev/null || true
    '';
  };
in
{
  environment.systemPackages = [
    obs-doctor
    obs-analyst
    obs-triage
    obs-diary
  ];

  systemd = {
    services = {
      obs-doctor = {
        description = "Observatory — nightly failed-service diagnosis";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = hardenedService // {
          ExecStart = "${obs-doctor}/bin/obs-doctor";
        };
      };
      obs-analyst = {
        description = "Observatory — weekly flake lint + git summary";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = hardenedService // {
          ExecStart = "${obs-analyst}/bin/obs-analyst";
        };
      };
      obs-triage = {
        description = "Observatory — 4-hourly log anomaly triage";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = hardenedService // {
          ExecStart = "${obs-triage}/bin/obs-triage";
        };
      };
      obs-diary = {
        description = "Observatory — nightly personal diary reflection";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = hardenedService // {
          ExecStart = "${obs-diary}/bin/obs-diary";
        };
      };
    };

    timers = {
      obs-doctor = {
        description = "Observatory doctor timer — daily 07:00";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 07:00:00";
          Persistent = true;
          RandomizedDelaySec = "5m";
        };
      };
      obs-analyst = {
        description = "Observatory analyst timer — Saturday 05:00";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "Sat *-*-* 05:00:00";
          Persistent = true;
          RandomizedDelaySec = "15m";
        };
      };
      obs-triage = {
        description = "Observatory log-triage timer — every 4h";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 00/4:00:00";
          Persistent = true;
          RandomizedDelaySec = "10m";
        };
      };
      obs-diary = {
        description = "Observatory diary timer — daily 23:00";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 23:00:00";
          Persistent = true;
          RandomizedDelaySec = "20m";
        };
      };
    };
  };
}
