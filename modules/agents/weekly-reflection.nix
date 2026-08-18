/*
  agents/weekly-reflection.nix — Sunday-evening personal review.

  Pipeline
  --------
  Every Sunday at 20:30:
    1. Pull last-7-days Memos posts   (via /api/v1/memo?rowStatus=NORMAL&limit=50)
    2. Pull Vikunja tasks completed   (via /api/v1/tasks?filter=done_at>now-7d)
    3. Pull Immich weekly stats       (via /api/statistics)
    4. Pull Miniflux read count       (via /v1/entries?status=read&…)
    5. LLM composes a weekly review:
         - "cosa hai fatto" (highlight 3-5 items)
         - "cosa hai imparato" (dai memos / articoli letti)
         - "cosa è rimasto aperto" (task ancora TODO importanti)
         - "prompt per la prossima settimana" (1-2 domande di riflessione)
    6. Save markdown in $STATE_DIR/<date>-review.md
    7. Push to ntfy topic `personal` + auto-create Memos entry `weekly-review`.

  Uses qwen2.5:14b for prose quality. Zero external calls.
*/
{ pkgs, lib, ... }:
let
  agents = import ./lib.nix { inherit pkgs lib; };
in
agents.mkAgent {
  name = "weekly-reflection";
  description = "Sunday-evening weekly personal review";
  schedule = "Sun *-*-* 20:30:00";
  script = ''
        MODEL="''${LLM_MODEL:-qwen2.5:14b}"
        MEMOS_URL="''${MEMOS_URL:-http://127.0.0.1:5230}"
        VIKUNJA_URL="''${VIKUNJA_URL:-http://127.0.0.1:3456}"
        IMMICH_URL="''${IMMICH_URL:-http://127.0.0.1:2283}"
        MINIFLUX_URL="''${MINIFLUX_URL:-http://127.0.0.1:8081}"

        MFX_TOKEN=""
        [ -r /var/lib/agents/miniflux-token ] && MFX_TOKEN="$(cat /var/lib/agents/miniflux-token)"
        VIKUNJA_TOKEN=""
        [ -r /var/lib/agents/vikunja-token ]  && VIKUNJA_TOKEN="$(cat /var/lib/agents/vikunja-token)"
        IMMICH_TOKEN=""
        [ -r /var/lib/agents/immich-token ]   && IMMICH_TOKEN="$(cat /var/lib/agents/immich-token)"

        WEEK_AGO=$(date -u -d '7 days ago' +%s)

        MEMOS=$(curl -sf "$MEMOS_URL/api/v1/memo?rowStatus=NORMAL&limit=100" 2>/dev/null \
          | jq -c "[.[] | select((.createdTs // 0) >= $WEEK_AGO) | {ts:.createdTs, content:.content}]" \
          || echo '[]')

        TASKS_DONE="[]"
        if [ -n "$VIKUNJA_TOKEN" ]; then
          TASKS_DONE=$(curl -sf -H "Authorization: Bearer $VIKUNJA_TOKEN" \
            "$VIKUNJA_URL/api/v1/tasks/all?filter=done=true&filter_include_nulls=false&per_page=100" 2>/dev/null \
            | jq -c '[.[] | {title:.title, done_at:.done_at}]' || echo '[]')
        fi

        IMMICH_STATS="{}"
        if [ -n "$IMMICH_TOKEN" ]; then
          IMMICH_STATS=$(curl -sf -H "x-api-key: $IMMICH_TOKEN" \
            "$IMMICH_URL/api/server/statistics" 2>/dev/null || echo '{}')
        fi

        MFX_READ_COUNT=0
        if [ -n "$MFX_TOKEN" ]; then
          MFX_READ_COUNT=$(curl -sf -H "X-Auth-Token: $MFX_TOKEN" \
            "$MINIFLUX_URL/v1/entries?status=read&limit=1" 2>/dev/null \
            | jq -r '.total // 0' || echo 0)
        fi

        USER_INPUT=$(jq -n \
          --argjson memos "$MEMOS" \
          --argjson tasks "$TASKS_DONE" \
          --argjson immich "$IMMICH_STATS" \
          --arg articles "$MFX_READ_COUNT" \
          '{memos:$memos, tasks_completed:$tasks, immich:$immich, articles_read:($articles|tonumber)}')

        PROMPT=$(cat <<'EOF'
    Sei un coach personale che scrive una review settimanale. In input ricevi:
      - memos: micro-note del utente della settimana
      - tasks_completed: task chiusi su Vikunja
      - immich: statistiche foto (assets totali)
      - articles_read: numero articoli chiusi su Miniflux

    Componi una review markdown in italiano con questa struttura ESATTA:

    ## Highlight
    3-5 punti concreti — cose fatte, appreso o vissuto.

    ## Cosa ho imparato
    Sintesi dei temi emersi dai memos e dagli articoli. Massimo 3 bullet.

    ## Cosa è rimasto aperto
    Task o intenzioni ancora non chiuse. Nomina 2-3, priorità.

    ## Domande per la prossima settimana
    1-2 domande di riflessione, aperte, non retoriche.

    Tono: caldo ma essenziale, evita superlativi vuoti. Se un input è vuoto
    (zero memos, zero task), dì "settimana silente" in una riga per quella
    sezione, senza inventare. Max 400 parole totali.
    EOF
        )

        PAYLOAD=$(jq -n \
          --arg model "$MODEL" \
          --arg system "$PROMPT" \
          --arg user "$USER_INPUT" \
          '{model:$model, stream:false, system:$system, prompt:$user,
            options:{temperature:0.45, num_ctx:16384}}')

        REVIEW=$(curl -sf "$OLLAMA_URL/api/generate" \
          -H 'content-type: application/json' -d "$PAYLOAD" \
          | jq -r '.response')

        [ -z "$REVIEW" ] && { echo "empty review"; exit 1; }

        WEEK=$(date +%Y-W%V)
        printf '%s' "$REVIEW" > "$STATE_DIR/$WEEK-review.md"

        curl -sf -X POST "$NTFY_URL/personal" \
          -H "Title: Weekly review — $WEEK" \
          -H "Priority: default" \
          -H "Tags: sparkles,scroll" \
          -H "Markdown: yes" \
          ''${NTFY_TOKEN:+ -H "Authorization: Bearer $NTFY_TOKEN"} \
          --data-binary "$REVIEW"

        # Auto-post to Memos so the review lives inside the personal timeline.
        if [ -r /var/lib/agents/memos-token ]; then
          MEMOS_TOKEN="$(cat /var/lib/agents/memos-token)"
          curl -sf -X POST "$MEMOS_URL/api/v1/memo" \
            -H "Authorization: Bearer $MEMOS_TOKEN" \
            -H 'content-type: application/json' \
            -d "$(jq -n --arg content "$REVIEW" '{content:$content, visibility:"PRIVATE"}')" \
            >/dev/null || true
        fi
  '';
}
