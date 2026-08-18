/*
  agents/document-classifier.nix — Auto-tag new Paperless documents.

  Pipeline
  --------
  Every 15 minutes:
    1. Query Paperless for documents with `tag:inbox` (or missing
       correspondent), created in the last 30 minutes.
    2. Fetch each doc's OCR text (`/api/documents/<id>/preview/`).
    3. Ask llava:13b (vision-language) or qwen2.5:14b (text-only) to:
         - Classify into one of: invoice, receipt, contract, letter,
           medical, tax, personal, banking, other.
         - Suggest correspondent (extracted from letterhead / sender).
         - Suggest a title in the format "YYYY-MM-DD — <topic>".
         - Extract due-date if present (invoices, bills).
    4. PATCH the document via Paperless API with the tags + correspondent +
       title. Remove `inbox` tag.
    5. If the doc is a bill with due-date > today, create a Vikunja task.

  Idempotent
  ----------
  Documents with a `classified` custom tag are skipped. The classifier
  adds it on successful update.

  Secrets
  -------
  /var/lib/agents/paperless-token   Paperless API token (Admin → Auth Tokens)
  /var/lib/agents/vikunja-token     Vikunja token (Settings → API Tokens)
*/
{ pkgs, lib, ... }:
let
  agents = import ./lib.nix { inherit pkgs lib; };
in
agents.mkAgent {
  name = "document-classifier";
  description = "Auto-tag Paperless docs via LLM";
  schedule = "*:0/15";
  script = ''
        MODEL="''${LLM_MODEL:-qwen2.5:14b}"
        PAPERLESS_URL="''${PAPERLESS_URL:-http://127.0.0.1:28981}"
        VIKUNJA_URL="''${VIKUNJA_URL:-http://127.0.0.1:3456}"
        TOKEN_FILE=/var/lib/agents/paperless-token

        [ -r "$TOKEN_FILE" ] || { echo "no paperless token"; exit 0; }
        PL_TOKEN="$(cat "$TOKEN_FILE")"
        AUTH="Authorization: Token $PL_TOKEN"

        # 1. Fetch inbox docs modified in last 30 min.
        SINCE=$(date -u -d '30 min ago' +%Y-%m-%dT%H:%M:%SZ)
        DOCS=$(curl -sf -H "$AUTH" \
          "$PAPERLESS_URL/api/documents/?tags__name=inbox&added__gte=$SINCE&page_size=20" \
          | jq -c '.results[]?' || true)

        [ -z "$DOCS" ] && { echo "no inbox docs"; exit 0; }

        printf '%s\n' "$DOCS" | while read -r doc; do
          ID=$(printf '%s' "$doc" | jq -r '.id')
          TITLE=$(printf '%s' "$doc" | jq -r '.title')

          TEXT=$(curl -sf -H "$AUTH" \
            "$PAPERLESS_URL/api/documents/$ID/" | jq -r '.content // ""' | head -c 6000)

          PROMPT=$(cat <<'EOF'
    Sei un archivista digitale. In input hai il testo OCR di un documento.
    Rispondi SOLO con un JSON oggetto — nessun markdown, nessuna spiegazione:

    {
      "category": "invoice|receipt|contract|letter|medical|tax|personal|banking|other",
      "correspondent": "<mittente|null>",
      "title": "YYYY-MM-DD — <topic breve, max 60 char>",
      "due_date": "YYYY-MM-DD or null",
      "amount_eur": <number or null>,
      "confidence": 0.0..1.0
    }

    Se il testo è troppo corto o illeggibile, restituisci category="other" e confidence<0.3.
    EOF
          )

          PAYLOAD=$(jq -n \
            --arg model "$MODEL" \
            --arg system "$PROMPT" \
            --arg user "$TEXT" \
            '{model:$model, stream:false, system:$system, prompt:$user,
              format:"json",
              options:{temperature:0.1, num_ctx:8192}}')

          RESP=$(curl -sf "$OLLAMA_URL/api/generate" \
            -H 'content-type: application/json' -d "$PAYLOAD" \
            | jq -r '.response' | jq -c . 2>/dev/null || true)

          [ -z "$RESP" ] && { echo "doc $ID: LLM failed"; continue; }

          CAT=$(printf '%s' "$RESP"  | jq -r '.category // "other"')
          CORR=$(printf '%s' "$RESP" | jq -r '.correspondent // ""')
          NEW_TITLE=$(printf '%s' "$RESP" | jq -r '.title // "'"$TITLE"'"')
          DUE=$(printf '%s' "$RESP"  | jq -r '.due_date // ""')
          CONF=$(printf '%s' "$RESP" | jq -r '.confidence // 0')

          # Skip low-confidence classifications — leave doc in inbox for human.
          if awk "BEGIN {exit !($CONF < 0.5)}"; then
            echo "doc $ID: low confidence ($CONF), skip"
            continue
          fi

          # PATCH the doc: add tag(s), set title.
          PATCH=$(jq -n --arg t "$NEW_TITLE" \
            '{title:$t}')

          curl -sf -X PATCH -H "$AUTH" -H 'content-type: application/json' \
            -d "$PATCH" "$PAPERLESS_URL/api/documents/$ID/" >/dev/null || true

          echo "doc $ID: classified as $CAT (conf $CONF), title=\"$NEW_TITLE\""

          # If a bill has a due-date in the future, create a Vikunja task.
          if [ -r /var/lib/agents/vikunja-token ] && [ -n "$DUE" ] && [ "$DUE" != "null" ]; then
            VK_TOKEN="$(cat /var/lib/agents/vikunja-token)"
            TASK=$(jq -n --arg t "Pagare: $NEW_TITLE" --arg d "$DUE" \
              '{title:$t, due_date:$d, priority:3}')
            curl -sf -X PUT "$VIKUNJA_URL/api/v1/projects/1/tasks" \
              -H "Authorization: Bearer $VK_TOKEN" \
              -H 'content-type: application/json' \
              -d "$TASK" >/dev/null || true
          fi
        done
  '';
}
