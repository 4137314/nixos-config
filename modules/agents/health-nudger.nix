/*
  agents/health-nudger.nix — Gentle activity/engagement checker.

  Rationale
  ---------
  If the operator writes no memos, closes no tasks, uploads no photos
  and reads no articles for N days, something is off — burnout, illness,
  distraction. This agent doesn't nag; it asks one open question
  (LLM-generated so it's not always the same).

  Pipeline
  --------
  Daily at 21:00:
    1. Count activity in the last 72h across:
         - Memos posts (>0)
         - Vikunja tasks completed (>0)
         - Immich assets added (>0)
         - Miniflux entries marked read (>3)
    2. If ALL indicators are ≤ threshold, generate a one-line prompt
       ("cosa ti sta occupando la mente in questi giorni?"-style) via
       llama3.2:3b (small, fast, warm).
    3. Post as a low-priority ntfy to topic `personal`.

  If ANY indicator is above threshold, do nothing (no positive feedback
  loop — the goal is a quiet backstop, not a habit tracker).
*/
{ pkgs, lib, ... }:
let
  agents = import ./lib.nix { inherit pkgs lib; };
in
agents.mkAgent {
  name = "health-nudger";
  description = "Daily activity checkpoint — gentle nudge on silence";
  schedule = "*-*-* 21:00:00";
  script = ''
        MODEL="''${LLM_MODEL:-llama3.2:3b}"
        MEMOS_URL="''${MEMOS_URL:-http://127.0.0.1:5230}"
        VIKUNJA_URL="''${VIKUNJA_URL:-http://127.0.0.1:3456}"
        IMMICH_URL="''${IMMICH_URL:-http://127.0.0.1:2283}"
        MINIFLUX_URL="''${MINIFLUX_URL:-http://127.0.0.1:8081}"

        T=$(date -u -d '72 hours ago' +%s)

        MEMOS=$(curl -sf "$MEMOS_URL/api/v1/memo?rowStatus=NORMAL&limit=50" 2>/dev/null \
          | jq -r "[.[] | select((.createdTs // 0) >= $T)] | length" || echo 0)

        TASKS=0
        if [ -r /var/lib/agents/vikunja-token ]; then
          VK_TOKEN="$(cat /var/lib/agents/vikunja-token)"
          TASKS=$(curl -sf -H "Authorization: Bearer $VK_TOKEN" \
            "$VIKUNJA_URL/api/v1/tasks/all?filter=done=true&per_page=50" 2>/dev/null \
            | jq -r "[.[]? | select((.done_at // \"1970-01-01T00:00:00Z\") | fromdateiso8601 >= $T)] | length" || echo 0)
        fi

        IMMICH_ADDED=0
        if [ -r /var/lib/agents/immich-token ]; then
          IM_TOKEN="$(cat /var/lib/agents/immich-token)"
          # Immich has a /api/search/metadata endpoint; count assets uploaded in window.
          IMMICH_ADDED=$(curl -sf -H "x-api-key: $IM_TOKEN" \
            -X POST "$IMMICH_URL/api/search/metadata" \
            -H 'content-type: application/json' \
            -d "$(jq -n --arg t "$(date -u -d '72 hours ago' +%Y-%m-%dT%H:%M:%SZ)" \
              '{takenAfter:$t, size:1, page:1}')" 2>/dev/null \
            | jq -r '.assets.total // 0' || echo 0)
        fi

        ARTICLES=0
        if [ -r /var/lib/agents/miniflux-token ]; then
          MFX_TOKEN="$(cat /var/lib/agents/miniflux-token)"
          ARTICLES=$(curl -sf -H "X-Auth-Token: $MFX_TOKEN" \
            "$MINIFLUX_URL/v1/entries?status=read&after=$T&limit=1" 2>/dev/null \
            | jq -r '.total // 0' || echo 0)
        fi

        echo "72h activity: memos=$MEMOS tasks=$TASKS immich=$IMMICH_ADDED articles=$ARTICLES"

        # Threshold: quiet = memos<=0 AND tasks<=0 AND immich<=0 AND articles<=3.
        if [ "$MEMOS" -le 0 ] && [ "$TASKS" -le 0 ] && [ "$IMMICH_ADDED" -le 0 ] && [ "$ARTICLES" -le 3 ]; then
          PROMPT=$(cat <<'EOF'
    Genera UNA singola domanda gentile in italiano, aperta, non retorica,
    non giudicante, che invita a scrivere una micro-nota su cosa sta
    occupando la mente in questi giorni. Max 15 parole. NO emoji. Solo la
    domanda, nient'altro.
    EOF
          )
          PAYLOAD=$(jq -n \
            --arg model "$MODEL" \
            --arg system "$PROMPT" \
            --arg user "" \
            '{model:$model, stream:false, system:$system, prompt:$user,
              options:{temperature:0.9, num_ctx:2048, num_predict:60}}')

          QUESTION=$(curl -sf "$OLLAMA_URL/api/generate" \
            -H 'content-type: application/json' -d "$PAYLOAD" \
            | jq -r '.response' | tr -d '\n' | head -c 200)

          [ -z "$QUESTION" ] && QUESTION="Come stai, davvero?"

          curl -sf -X POST "$NTFY_URL/personal" \
            -H "Title: Checkpoint" \
            -H "Priority: low" \
            -H "Tags: seedling" \
            ''${NTFY_TOKEN:+ -H "Authorization: Bearer $NTFY_TOKEN"} \
            --data "$QUESTION"
        fi
  '';
}
