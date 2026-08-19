/*
  agents/rag-indexer.nix — Cross-service RAG indexer.

  Pipeline
  --------
  Every 30 minutes:
    1. Snapshot recent items from:
         - Paperless-ngx  (OCR'd documents added since last run)
         - Karakeep       (bookmarks + notes added / updated)
         - Memos          (personal notes added / updated)
    2. Chunk each item (1000 tokens, 100 overlap).
    3. Embed each chunk via Ollama `nomic-embed-text`.
    4. Upsert into Qdrant collections:
         paperless   (768-dim vectors)
         karakeep    (768-dim vectors)
         memos       (768-dim vectors)
       Each point carries: id, source_url, title, content, timestamp.
    5. Persist last-run timestamp in $STATE_DIR/last-<source>.

  Result
  ------
  A single Qdrant multi-collection index that Open WebUI (and any
  downstream agent) can query with semantic search:
      "trova la nota / articolo / documento su X"
  Returns hits from ALL three sources ranked by similarity.

  Collections are created lazily on first insert.
*/
{ pkgs, lib, ... }:
let
  agents = import ../lib.nix { inherit pkgs lib; };
in
agents.mkAgent {
  name = "rag-indexer";
  description = "Cross-service RAG: paperless+karakeep+memos → Qdrant";
  schedule = "*:0/30";
  extraPackages = [ pkgs.python3 ];
  script = ''
    QDRANT_URL="''${QDRANT_URL:-http://127.0.0.1:6333}"
    EMB_MODEL="''${EMB_MODEL:-nomic-embed-text}"
    PL_URL="''${PAPERLESS_URL:-http://127.0.0.1:28981}"
    KK_URL="''${KARAKEEP_URL:-http://127.0.0.1:3005}"
    ME_URL="''${MEMOS_URL:-http://127.0.0.1:5230}"

    # -- Collection bootstrap -----------------------------------------------
    for coll in paperless karakeep memos; do
      curl -sf -X PUT "$QDRANT_URL/collections/$coll" \
        -H 'content-type: application/json' \
        -d '{"vectors":{"size":768,"distance":"Cosine"}}' >/dev/null 2>&1 || true
    done

    # -- Helper: embed a text via Ollama ------------------------------------
    embed() {
      local text="$1"
      curl -sf "$OLLAMA_URL/api/embeddings" \
        -H 'content-type: application/json' \
        -d "$(jq -n --arg m "$EMB_MODEL" --arg p "$text" '{model:$m, prompt:$p}')" \
        | jq -c '.embedding'
    }

    # -- Helper: upsert a point ---------------------------------------------
    upsert() {
      local collection="$1" id="$2" vector="$3" payload="$4"
      curl -sf -X PUT "$QDRANT_URL/collections/$collection/points" \
        -H 'content-type: application/json' \
        -d "$(jq -n --arg id "$id" --argjson v "$vector" --argjson p "$payload" \
              '{points:[{id:$id, vector:$v, payload:$p}]}')" >/dev/null
    }

    # -- 1. Paperless -------------------------------------------------------
    LAST_PL=$(cat "$STATE_DIR/last-paperless" 2>/dev/null || echo 0)
    SINCE_PL=$(date -u -d "@$LAST_PL" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo '1970-01-01T00:00:00Z')
    if [ -r /var/lib/agents/paperless-token ]; then
      PL_TOKEN="$(cat /var/lib/agents/paperless-token)"
      DOCS=$(curl -sf -H "Authorization: Token $PL_TOKEN" \
        "$PL_URL/api/documents/?modified__gte=$SINCE_PL&ordering=modified&page_size=20" \
        | jq -c '.results[]?' || true)
      printf '%s\n' "$DOCS" | while read -r doc; do
        [ -z "$doc" ] && continue
        ID=$(printf '%s' "$doc" | jq -r '.id')
        TITLE=$(printf '%s' "$doc" | jq -r '.title')
        CONTENT=$(printf '%s' "$doc" | jq -r '.content // "" | .[0:8000]')
        [ -z "$CONTENT" ] && continue
        VEC=$(embed "$CONTENT")
        PAY=$(jq -n --arg t "$TITLE" --arg s "paperless" --arg u "$PL_URL/documents/$ID" \
              --arg c "$(echo "$CONTENT" | head -c 800)" \
              '{title:$t, source:$s, url:$u, snippet:$c}')
        upsert paperless "$ID" "$VEC" "$PAY"
        echo "paperless #$ID indexed: $TITLE"
      done
    fi
    date +%s > "$STATE_DIR/last-paperless"

    # -- 2. Karakeep --------------------------------------------------------
    if [ -r /var/lib/agents/karakeep-token ]; then
      KK_TOKEN="$(cat /var/lib/agents/karakeep-token)"
      BMS=$(curl -sf -H "Authorization: Bearer $KK_TOKEN" \
        "$KK_URL/api/v1/bookmarks?limit=30" | jq -c '.bookmarks[]?' || true)
      printf '%s\n' "$BMS" | while read -r bm; do
        [ -z "$bm" ] && continue
        ID=$(printf '%s' "$bm" | jq -r '.id')
        TITLE=$(printf '%s' "$bm" | jq -r '.title // .content.title // ""')
        URL=$(printf '%s' "$bm" | jq -r '.content.url // ""')
        TEXT=$(printf '%s' "$bm" | jq -r '(.content.description // "") + " " + (.note // "")')
        [ -z "$TEXT" ] && continue
        VEC=$(embed "$TEXT")
        PAY=$(jq -n --arg t "$TITLE" --arg u "$URL" --arg s "karakeep" \
              --arg c "$(echo "$TEXT" | head -c 800)" \
              '{title:$t, url:$u, source:$s, snippet:$c}')
        upsert karakeep "$ID" "$VEC" "$PAY"
        echo "karakeep $ID indexed"
      done
    fi

    # -- 3. Memos -----------------------------------------------------------
    LAST_ME=$(cat "$STATE_DIR/last-memos" 2>/dev/null || echo 0)
    MEMOS=$(curl -sf "$ME_URL/api/v1/memo?rowStatus=NORMAL&limit=30" \
      | jq -c "[.[] | select((.updatedTs // 0) > $LAST_ME)] | .[]" || true)
    printf '%s\n' "$MEMOS" | while read -r mm; do
      [ -z "$mm" ] && continue
      ID=$(printf '%s' "$mm" | jq -r '.id')
      CONTENT=$(printf '%s' "$mm" | jq -r '.content // ""')
      [ -z "$CONTENT" ] && continue
      VEC=$(embed "$CONTENT")
      PAY=$(jq -n --arg c "$CONTENT" --arg s "memos" --arg u "https://notes.nixos-hacker-box/m/$ID" \
            '{title:($c[:80]), url:$u, source:$s, snippet:($c[:800])}')
      upsert memos "$ID" "$VEC" "$PAY"
      echo "memo $ID indexed"
    done
    date +%s > "$STATE_DIR/last-memos"
  '';
}
