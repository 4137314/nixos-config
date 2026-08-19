/*
  agents/news-digest.nix — Daily news digest from Miniflux → LLM → ntfy.

  Pipeline
  --------
  Every day at 07:00:
    1. Fetch unread entries from Miniflux via its JSON API.
    2. Group by feed category (news / tech / finance / hobby …).
    3. Send each group to Ollama with a summarisation prompt.
    4. Compose an HTML+markdown digest.
    5. Push to ntfy topic `news` with high priority.
    6. Mark digested entries as read in Miniflux.

  Secrets
  -------
  Miniflux API token lives at /var/lib/agents/miniflux-token (400 owned by
  agent-news-digest). Create with:
      curl -u admin:PASS http://127.0.0.1:8081/v1/users/1/api-keys ...
  or generate through the Miniflux UI (Settings → API Keys).
*/
{ pkgs, lib, ... }:
let
  agents = import ../lib.nix { inherit pkgs lib; };
in
agents.mkAgent {
  name = "news-digest";
  description = "Daily Miniflux → LLM → ntfy news digest";
  schedule = "*-*-* 07:00:00";
  extraServiceConfig.serviceConfig.ReadWritePaths = [ "/var/lib/agents/news-digest" ];
  script = ''
        MODEL="''${LLM_MODEL:-qwen2.5:14b}"
        MINIFLUX_URL="''${MINIFLUX_URL:-http://127.0.0.1:8081}"
        MINIFLUX_TOKEN_FILE="/var/lib/agents/miniflux-token"

        if [ ! -r "$MINIFLUX_TOKEN_FILE" ]; then
          echo "missing Miniflux token at $MINIFLUX_TOKEN_FILE — skip"
          exit 0
        fi

        MFX_TOKEN="$(cat "$MINIFLUX_TOKEN_FILE")"

        # Fetch unread entries (max 100), grouped by category.
        ENTRIES=$(curl -sf -H "X-Auth-Token: $MFX_TOKEN" \
          "$MINIFLUX_URL/v1/entries?status=unread&limit=100&order=published_at&direction=desc")

        COUNT=$(printf '%s' "$ENTRIES" | jq -r '.total')

        if [ "$COUNT" -eq 0 ]; then
          echo "no unread entries — skip"
          exit 0
        fi

        # Build a compact prompt: title + feed + one-sentence excerpt.
        ARTICLES=$(printf '%s' "$ENTRIES" \
          | jq -r '.entries[] | "- [\(.feed.category.title // "misc")] \(.feed.title): \(.title) — \((.content // "" | .[0:200] | gsub("\\s+";" ")))"')

        PROMPT=$(cat <<'EOF'
    You are a personal news editor. Below is a list of headlines and excerpts
    from RSS feeds subscribed by the operator. Produce a single Italian
    digest with these rules:

      * Group by category header ( "## Tecnologia", "## Finanza", "## Mondo", "## Hobby" etc).
      * Each item is 1-2 sentences, factual, no hype, no clickbait rewriting.
      * Drop items that are duplicates, PR pieces, or off-topic.
      * At the end, add a "## Consigli di lettura" section with the 3 most
        substantive articles ranked by expected depth.

    Output plain markdown. Max 800 words total.
    EOF
        )

        PAYLOAD=$(jq -n \
          --arg model "$MODEL" \
          --arg system "$PROMPT" \
          --arg user "$ARTICLES" \
          '{model:$model, stream:false, system:$system, prompt:$user,
            options:{temperature:0.3, num_ctx:16384}}')

        DIGEST=$(curl -sf "$OLLAMA_URL/api/generate" \
          -H 'content-type: application/json' -d "$PAYLOAD" \
          | jq -r '.response')

        if [ -z "$DIGEST" ]; then
          echo "empty digest — abort"
          exit 1
        fi

        TODAY=$(date +%Y-%m-%d)
        printf '%s' "$DIGEST" > "$STATE_DIR/$TODAY-digest.md"

        # ntfy: markdown supported via header format.
        curl -sf -X POST "$NTFY_URL/news" \
          -H "Title: Digest quotidiano — $TODAY ($COUNT articoli)" \
          -H "Priority: default" \
          -H "Tags: newspaper" \
          -H "Markdown: yes" \
          ''${NTFY_TOKEN:+ -H "Authorization: Bearer $NTFY_TOKEN"} \
          --data-binary "$DIGEST"

        # Mark all fetched entries as read.
        IDS=$(printf '%s' "$ENTRIES" | jq -c '[.entries[].id]')
        curl -sf -X PUT "$MINIFLUX_URL/v1/entries" \
          -H "X-Auth-Token: $MFX_TOKEN" \
          -H "content-type: application/json" \
          -d "{\"entry_ids\": $IDS, \"status\": \"read\"}" >/dev/null || true
  '';
}
