/*
  agents/bookmark-summariser.nix — TL;DR every fresh Karakeep bookmark.

  Pipeline
  --------
  Every 20 minutes:
    1. Fetch Karakeep bookmarks added in the last 30 minutes without a
       `summary` annotation (`GET /api/v1/bookmarks?limit=50`).
    2. For each URL:
         - Ask Firecrawl (http://firecrawl:3002) to render + return markdown.
         - Feed the markdown into qwen2.5:14b with a summarisation prompt.
    3. Update the Karakeep bookmark with:
         - `note`: the 3-bullet TL;DR
         - `tag`: LLM-suggested tags (max 5)
    4. Log to ntfy topic `personal` only if the bookmark's tag matches
       a user-defined "hot" list (default: `paper,tutorial,security`).

  Secrets
  -------
  /var/lib/agents/karakeep-token
  /var/lib/agents/firecrawl-token  (optional — Firecrawl runs open by default)
*/
{ pkgs, lib, ... }:
let
  agents = import ../lib.nix { inherit pkgs lib; };
in
agents.mkAgent {
  name = "bookmark-summariser";
  description = "Auto-summarise new Karakeep bookmarks via LLM";
  schedule = "*:0/20";
  script = ''
        MODEL="''${LLM_MODEL:-qwen2.5:14b}"
        KK_URL="''${KARAKEEP_URL:-http://127.0.0.1:3005}"
        FC_URL="''${FIRECRAWL_URL:-http://127.0.0.1:3002}"
        HOT_TAGS="''${HOT_TAGS:-paper,tutorial,security,research}"
        TOKEN_FILE=/var/lib/agents/karakeep-token

        [ -r "$TOKEN_FILE" ] || { echo "no karakeep token"; exit 0; }
        KK_TOKEN="$(cat "$TOKEN_FILE")"
        AUTH="Authorization: Bearer $KK_TOKEN"

        SINCE=$(date -u -d '30 min ago' +%s)

        BOOKMARKS=$(curl -sf -H "$AUTH" \
          "$KK_URL/api/v1/bookmarks?limit=50" \
          | jq -c "[.bookmarks[]? | select(.content.type==\"link\" and (.createdAt|fromdateiso8601) > $SINCE and (.note==\"\" or .note==null))]")

        COUNT=$(printf '%s' "$BOOKMARKS" | jq -r 'length')
        [ "$COUNT" -eq 0 ] && { echo "no new bookmarks"; exit 0; }

        echo "processing $COUNT bookmarks"

        printf '%s' "$BOOKMARKS" | jq -c '.[]' | while read -r bm; do
          ID=$(printf   '%s' "$bm" | jq -r '.id')
          URL=$(printf  '%s' "$bm" | jq -r '.content.url')
          TITLE=$(printf '%s' "$bm" | jq -r '.title // .content.title // ""')

          # 1. Fetch clean markdown via Firecrawl.
          MD=$(curl -sf -X POST "$FC_URL/v1/scrape" \
            -H 'content-type: application/json' \
            -d "$(jq -n --arg url "$URL" '{url:$url, formats:["markdown"], onlyMainContent:true}')" \
            | jq -r '.data.markdown // ""' | head -c 12000 || true)

          [ -z "$MD" ] && { echo "  [$ID] firecrawl empty for $URL — skip"; continue; }

          # 2. Summarise.
          PROMPT=$(cat <<'EOF'
    Sei un lettore veloce e critico. In input hai il contenuto markdown di
    un articolo. Rispondi SOLO con questo JSON:

    {
      "tldr": ["bullet 1 (max 25 parole)", "bullet 2", "bullet 3"],
      "tags": ["tag1", "tag2"],
      "reading_time_min": <int>,
      "quality": "high|medium|low|spam"
    }

    Regole:
      * bullet in italiano, fattuali, evita "l'autore dice", vai diretto.
      * tags in lowercase, sostantivi singoli o composti-con-trattini.
      * tag da almeno uno di questi se applicabile:
        paper, tutorial, security, opinion, news, tool, howto, deep-dive,
        research, culture, business, health, code.
      * quality=spam per pagine che sono principalmente pubblicità/SEO.
    EOF
          )

          PAYLOAD=$(jq -n \
            --arg model "$MODEL" \
            --arg system "$PROMPT" \
            --arg user "$MD" \
            '{model:$model, stream:false, system:$system, prompt:$user,
              format:"json",
              options:{temperature:0.2, num_ctx:16384}}')

          RESP=$(curl -sf "$OLLAMA_URL/api/generate" \
            -H 'content-type: application/json' -d "$PAYLOAD" \
            | jq -r '.response' | jq -c . 2>/dev/null || true)

          [ -z "$RESP" ] && { echo "  [$ID] LLM empty — skip"; continue; }

          TLDR=$(printf '%s' "$RESP" | jq -r '.tldr | map("- " + .) | join("\n")')
          TAGS=$(printf '%s' "$RESP" | jq -c '.tags')
          QUAL=$(printf '%s' "$RESP" | jq -r '.quality')

          # 3. Push tldr as `note` and tags.
          NOTE=$(printf '**TL;DR**\n\n%s\n\n_reading %s min · quality %s_\n' \
            "$TLDR" "$(printf '%s' "$RESP" | jq -r '.reading_time_min')" "$QUAL")

          curl -sf -X PATCH "$KK_URL/api/v1/bookmarks/$ID" \
            -H "$AUTH" -H 'content-type: application/json' \
            -d "$(jq -n --arg note "$NOTE" '{note:$note}')" >/dev/null || true

          # Attach tags (idempotent per Karakeep API).
          TAGS_ATTACH=$(jq -n --argjson t "$TAGS" '{tags:[$t[] | {tagName:.}]}')
          curl -sf -X POST "$KK_URL/api/v1/bookmarks/$ID/tags" \
            -H "$AUTH" -H 'content-type: application/json' \
            -d "$TAGS_ATTACH" >/dev/null || true

          # 4. If any tag is hot, ping ntfy.
          if printf '%s' "$TAGS" | jq -e --arg hot "$HOT_TAGS" \
              '. as $tags | ($hot | split(",")) | any(. as $h | $tags | index($h))' >/dev/null; then
            curl -sf -X POST "$NTFY_URL/personal" \
              -H "Title: New read — $TITLE" \
              -H "Priority: default" \
              -H "Tags: bookmark" \
              -H "Markdown: yes" \
              -H "Click: $URL" \
              ''${NTFY_TOKEN:+ -H "Authorization: Bearer $NTFY_TOKEN"} \
              --data-binary "$NOTE"
          fi

          echo "  [$ID] $TITLE → tags=$TAGS quality=$QUAL"
        done
  '';
}
