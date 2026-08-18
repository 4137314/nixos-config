/*
  agents/log-analyzer.nix — Autonomous log triage agent.

  Pipeline
  --------
  Every hour:
    1. Query Loki for {level=~"error|critical"} in the last 60 min.
    2. Deduplicate by log signature (first 40 chars of the message).
    3. Send the top 30 unique entries to Ollama with a triage prompt.
    4. LLM returns:
         - severity (info/warn/critical)
         - root-cause hypothesis
         - suggested action (systemctl status / journalctl / config file)
    5. If severity ≥ warn, push a summary to ntfy topic `system`.
    6. Persist last-run timestamp in $STATE_DIR/last-run.

  Idempotency
  -----------
  Loki is queried by absolute timestamp window, not by "since last run" —
  a missed hour is a missed hour, not a doubled scan.
*/
{ pkgs, lib, ... }:
let
  agents = import ./lib.nix { inherit pkgs lib; };
in
agents.mkAgent {
  name = "log-analyzer";
  description = "Hourly Loki triage — errors summarised by local LLM";
  schedule = "hourly";
  extraPackages = [ pkgs.moreutils ];
  script = ''
        MODEL="''${LLM_MODEL:-qwen2.5:14b}"

        NOW=$(date -u +%s)
        ONE_HOUR_AGO=$((NOW - 3600))

        # Loki wants nanoseconds.
        START="''${ONE_HOUR_AGO}000000000"
        END="''${NOW}000000000"

        QUERY='{host="'"$HOSTNAME"'"} |~ "(?i)error|critical|fatal|panic|traceback"'

        LOGS=$(curl -sfG "$LOKI_URL/loki/api/v1/query_range" \
          --data-urlencode "query=$QUERY" \
          --data-urlencode "start=$START" \
          --data-urlencode "end=$END" \
          --data-urlencode "limit=500" \
          --data-urlencode "direction=backward" \
          | jq -r '.data.result[]?.values[]?[1]' \
          | awk '{ sig=substr($0,1,80); if (!seen[sig]++) print }' \
          | head -n 30 || true)

        if [ -z "$LOGS" ]; then
          echo "no error logs in the window"
          exit 0
        fi

        PROMPT=$(cat <<'EOF'
    You are a Linux systemd operator. Below is a batch of ERROR/CRITICAL log
    lines collected in the last hour on a NixOS home lab. For each distinct
    incident, output ONE JSON line with:

      {"severity":"info|warn|critical","unit":"<systemd unit or app name>",
       "one_liner":"<one-sentence description>",
       "hypothesis":"<probable root cause in one sentence>",
       "action":"<one command the operator should run to investigate>"}

    Skip lines that are transient or self-recovering. Group repeats. Return
    at most 5 JSON lines total. Nothing else — no markdown, no prose.
    EOF
        )

        PAYLOAD=$(jq -n \
          --arg model "$MODEL" \
          --arg system "$PROMPT" \
          --arg user "$LOGS" \
          '{model:$model, stream:false, system:$system, prompt:$user,
            options:{temperature:0.1, num_ctx:8192}}')

        RAW=$(curl -sf "$OLLAMA_URL/api/generate" -H 'content-type: application/json' -d "$PAYLOAD" \
          | jq -r '.response // empty')

        if [ -z "$RAW" ]; then
          echo "LLM returned empty response"
          exit 0
        fi

        # Filter to warn/critical only, then compose ntfy body.
        BODY=$(printf '%s\n' "$RAW" \
          | jq -c 'select(type=="object") | select(.severity=="warn" or .severity=="critical")' \
          | while read -r line; do
              UNIT=$(printf '%s' "$line" | jq -r '.unit')
              SEV=$(printf  '%s' "$line" | jq -r '.severity')
              ONE=$(printf  '%s' "$line" | jq -r '.one_liner')
              HYP=$(printf  '%s' "$line" | jq -r '.hypothesis')
              ACT=$(printf  '%s' "$line" | jq -r '.action')
              printf -- "▪ [%s] %s — %s\n  hypothesis: %s\n  action: %s\n\n" \
                "$SEV" "$UNIT" "$ONE" "$HYP" "$ACT"
            done || true)

        if [ -z "''${BODY:-}" ]; then
          echo "no warn/critical incidents after LLM triage"
          exit 0
        fi

        HIGHEST=$(printf '%s\n' "$RAW" \
          | jq -sr 'map(select(type=="object") | .severity)
                    | if any(.=="critical") then "critical"
                      elif any(.=="warn") then "warning"
                      else "default" end')

        # Send to ntfy.
        curl -sf -X POST "$NTFY_URL/system" \
          -H "Title: Log triage — $HIGHEST incidents" \
          -H "Priority: $HIGHEST" \
          -H "Tags: warning,gear" \
          ''${NTFY_TOKEN:+ -H "Authorization: Bearer $NTFY_TOKEN"} \
          --data-binary "$BODY"

        printf '%s\n' "$NOW" > "$STATE_DIR/last-run"
  '';
}
