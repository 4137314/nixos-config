/*
  agents/calendar-briefer.nix — Morning voice/text briefing.

  Pipeline
  --------
  Weekdays at 07:15 (before finance-brief at 07:30):
    1. Vikunja: tasks due today or overdue (`/api/v1/tasks/all?filter=…`).
    2. Nextcloud CalDAV: today's events (curl to
       `https://nextcloud.nixos-hacker-box/remote.php/dav/calendars/main/personal/`
       with basic auth from /var/lib/agents/nextcloud-creds).
    3. wttr.in offline fallback — actually we use open-meteo API (free,
       no key, no closed source).
    4. LLM composes a briefing.
    5. Push to ntfy topic `personal` with `Priority: high`.
    6. Optionally render TTS: POST to Piper (:10201) and store the mp3
       under $STATE_DIR/<date>-brief.mp3 — Home Assistant automations
       can play it on a media_player.

  Zero closed-source APIs. open-meteo is free + open (no auth).
*/
{ pkgs, lib, ... }:
let
  agents = import ../lib.nix { inherit pkgs lib; };
in
agents.mkAgent {
  name = "calendar-briefer";
  description = "Morning voice/text calendar+weather briefing";
  schedule = "Mon..Fri 07:15:00";
  script = ''
        MODEL="''${LLM_MODEL:-qwen2.5:14b}"
        VIKUNJA_URL="''${VIKUNJA_URL:-http://127.0.0.1:3456}"
        PIPER_URL="''${PIPER_URL:-http://127.0.0.1:10201}"
        LAT="''${LAT:-45.4642}"    # Milano — override with env
        LON="''${LON:-9.19}"

        # 1. Vikunja tasks due today or overdue.
        TASKS="[]"
        if [ -r /var/lib/agents/vikunja-token ]; then
          VK_TOKEN="$(cat /var/lib/agents/vikunja-token)"
          TODAY=$(date -u +%Y-%m-%dT23:59:59Z)
          TASKS=$(curl -sf -H "Authorization: Bearer $VK_TOKEN" \
            "$VIKUNJA_URL/api/v1/tasks/all?filter=done=false%26%26due_date<%22$TODAY%22&per_page=50" \
            | jq -c '[.[]?] | map({title, due_date, priority})' || echo '[]')
        fi

        # 2. Weather from open-meteo (open-source, no key).
        WX=$(curl -sf "https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&current=temperature_2m,weather_code,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code&timezone=auto&forecast_days=1" || echo '{}')

        # 3. Compose prompt.
        INPUT=$(jq -n \
          --argjson tasks "$TASKS" \
          --argjson weather "$WX" \
          '{tasks:$tasks, weather:$weather, date:(now|strftime("%A %-d %B %Y"))}')

        PROMPT=$(cat <<'EOF'
    Sei un briefer mattutino. In input hai la data, meteo giornaliero e task
    in scadenza / scaduti. Componi un briefing IN ITALIANO parlato ad alta
    voce, senza markdown, senza elenchi puntati, per essere sintetizzato
    da un TTS. Regole:

      1. Apri con "Buongiorno" + data espansa.
      2. Meteo: temperatura min/max, probabilità pioggia, vento se >15 km/h.
         Se codice meteo suggerisce brutto tempo, dai un consiglio pratico
         (ombrello, cappotto).
      3. Task: se ce ne sono, cita al massimo i 3 con priorità più alta o
         più in ritardo. Se sono zero, dì "agenda leggera".
      4. Chiudi con una frase corta di motivazione, non zuccherosa.

    Max 150 parole totali. NO emoji. NO markdown.
    EOF
        )

        PAYLOAD=$(jq -n \
          --arg model "$MODEL" \
          --arg system "$PROMPT" \
          --arg user "$INPUT" \
          '{model:$model, stream:false, system:$system, prompt:$user,
            options:{temperature:0.5, num_ctx:8192}}')

        BRIEF=$(curl -sf "$OLLAMA_URL/api/generate" \
          -H 'content-type: application/json' -d "$PAYLOAD" \
          | jq -r '.response')

        [ -z "$BRIEF" ] && exit 1

        TODAY_TAG=$(date +%Y-%m-%d)
        printf '%s' "$BRIEF" > "$STATE_DIR/$TODAY_TAG-brief.txt"

        # 4. TTS via Piper (openedai-speech OpenAI-compat).
        curl -sf -X POST "$PIPER_URL/v1/audio/speech" \
          -H 'content-type: application/json' \
          -d "$(jq -n --arg model tts-1 --arg voice it_IT-riccardo-x_low --arg input "$BRIEF" \
            '{model:$model, voice:$voice, input:$input, response_format:"mp3"}')" \
          --output "$STATE_DIR/$TODAY_TAG-brief.mp3" 2>/dev/null || true

        # 5. Push text to ntfy for the phone. TTS mp3 stays local for HA to play.
        curl -sf -X POST "$NTFY_URL/personal" \
          -H "Title: Briefing — $TODAY_TAG" \
          -H "Priority: high" \
          -H "Tags: sunrise" \
          ''${NTFY_TOKEN:+ -H "Authorization: Bearer $NTFY_TOKEN"} \
          --data-binary "$BRIEF"
  '';
}
