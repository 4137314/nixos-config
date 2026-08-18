/*
  agents/incident-analyst.nix — On-demand incident analyst.

  Trigger model
  -------------
  Not a timer. Exposed as a systemd `--user`-less service that other
  agents (or Grafana webhook, or a manual `systemctl start`) invoke to
  produce a structured triage of the current system state:

      sudo systemctl start agent-incident-analyst

  Pipeline
  --------
    1. Snapshot the current state:
         - `systemctl --failed`
         - `journalctl -p err..alert --since '2 hours ago' | tail -200`
         - `df -h` and free -h
         - Uptime and load
         - Firewall recent drops
    2. Ask Ollama for a triage report:
         - What is broken (unit + one-line why)
         - What can wait vs what needs a human now
         - Ordered checklist of commands to run
    3. Publish a summary to ntfy topic `system`, and store the full report
       in $STATE_DIR/incident-<epoch>.md so `journalctl` + Loki keep the
       history queryable.

  Automations
  -----------
  Grafana → alerting policy → webhook http://127.0.0.1:8123/incident calls
  Home Assistant which fires `shell_command: systemctl start
  agent-incident-analyst` (see modules/ai/home-assistant.nix).
*/
{ pkgs, lib, ... }:
let
  agents = import ./lib.nix { inherit pkgs lib; };
in
agents.mkAgent {
  name = "incident-analyst";
  description = "On-demand systemd + journal triage — LLM diagnosis";
  # This is manually triggered, but the module builder always sets a timer.
  # Set a far-future OnCalendar so the timer is essentially inert.
  schedule = "*-*-01 04:00:00"; # once a month, safety belt.
  persistent = false;
  extraServiceConfig.serviceConfig = {
    # Needs to read root-owned journal + systemd status.
    User = lib.mkForce "root";
    Group = lib.mkForce "root";
    # Relax the sandbox — the whole point is inspecting the host.
    ProtectSystem = lib.mkForce "full";
    ProtectHome = lib.mkForce "read-only";
    PrivateDevices = lib.mkForce false;
    ReadWritePaths = lib.mkForce [ "/var/lib/agents/incident-analyst" ];
  };
  extraPackages = with pkgs; [
    systemd
    util-linux
    procps
    iproute2
  ];
  script = ''
        MODEL="''${LLM_MODEL:-qwen2.5:14b}"

        STATE="$STATE_DIR/$(date +%Y-%m-%dT%H:%M:%S)"
        mkdir -p "$STATE"

        # -----------------------------------------------------------
        # 1. Snapshot host state.
        # -----------------------------------------------------------
        {
          echo "=== systemctl --failed ==="
          systemctl --failed --no-pager 2>&1 || true

          echo; echo "=== journalctl (err+alert, last 2h) ==="
          journalctl -p err..alert --since '2 hours ago' --no-pager 2>&1 | tail -n 200 || true

          echo; echo "=== disk usage ==="
          df -h 2>&1

          echo; echo "=== memory ==="
          free -h 2>&1

          echo; echo "=== load + uptime ==="
          uptime
          cat /proc/loadavg 2>/dev/null || true

          echo; echo "=== top 15 by CPU ==="
          ps -eo pid,ppid,comm,%cpu,%mem --sort=-%cpu 2>&1 | head -n 16

          echo; echo "=== recent firewall drops ==="
          journalctl -k --since '30 min ago' --no-pager 2>&1 | grep -i 'refused' | tail -n 30 || true
        } > "$STATE/snapshot.txt"

        # -----------------------------------------------------------
        # 2. LLM triage.
        # -----------------------------------------------------------
        PROMPT=$(cat <<'EOF'
    You are a senior SRE staring at a NixOS home lab in trouble. The input
    is a raw diagnostic snapshot. Produce a triage report in this exact
    markdown structure:

    ## Riepilogo
    One sentence: "sistema OK" or "N incidenti attivi".

    ## Incidenti attivi
    For each broken unit / anomaly:
      - **<unit or subsystem>** — one-line description.
        - Cause probabile: one sentence.
        - Impatto: one sentence.
        - Azione: exact command to run (as root) — one line.

    ## Da tenere d'occhio
    Bullet list of things not broken but suspicious (log spam, high CPU,
    disks over 80% used, etc.).

    ## Nessuna azione necessaria
    One line: services that are healthy.

    Rules:
      * No prose padding, no reassurance, no advice to "monitor closely".
      * If something is unclear from the snapshot, say so and stop guessing.
      * Italian output.
    EOF
        )

        PAYLOAD=$(jq -n \
          --arg model "$MODEL" \
          --arg system "$PROMPT" \
          --arg user "$(cat "$STATE/snapshot.txt")" \
          '{model:$model, stream:false, system:$system, prompt:$user,
            options:{temperature:0.15, num_ctx:16384}}')

        REPORT=$(curl -sf "$OLLAMA_URL/api/generate" \
          -H 'content-type: application/json' -d "$PAYLOAD" \
          | jq -r '.response')

        if [ -z "$REPORT" ]; then
          echo "LLM produced no report — see $STATE/snapshot.txt"
          exit 1
        fi

        printf '%s' "$REPORT" > "$STATE/report.md"

        # -----------------------------------------------------------
        # 3. Ntfy notification.
        # -----------------------------------------------------------
        HEAD=$(printf '%s' "$REPORT" | head -n 8)

        curl -sf -X POST "$NTFY_URL/system" \
          -H "Title: Incident triage — $HOSTNAME" \
          -H "Priority: high" \
          -H "Tags: rotating_light" \
          -H "Markdown: yes" \
          ''${NTFY_TOKEN:+ -H "Authorization: Bearer $NTFY_TOKEN"} \
          --data-binary "$HEAD

    _full report:_ $STATE/report.md"
  '';
}
