/*
  agents/finance-brief.nix — Morning finance brief.

  Pipeline
  --------
  Weekdays at 07:30:
    1. Pull portfolio snapshot from Ghostfolio API (positions, P&L today).
    2. Query public APIs for benchmark levels:
         - Yahoo Finance for S&P 500, EURO STOXX 50, FTSE MIB, gold, oil
         - CoinGecko for BTC, ETH
         - ECB for EUR/USD reference rate
    3. Ghostfolio holdings passed to LLM alongside benchmark deltas so the
       brief is CONTEXTUAL to the operator's actual positions.
    4. LLM generates:
         - Market snapshot bullet list
         - Portfolio commentary (winners / losers vs benchmark)
         - Watch list — 3 items to look at during the day
    5. Push to ntfy topic `finance`.

  Zero personally identifying data leaves the box — the LLM is local
  (Ollama), the APIs are read-only public endpoints.

  Secrets
  -------
  Ghostfolio bearer token at /var/lib/agents/ghostfolio-token (400).
  Generate from Ghostfolio UI → Settings → Get token.
*/
{ pkgs, lib, ... }:
let
  agents = import ./lib.nix { inherit pkgs lib; };
in
agents.mkAgent {
  name = "finance-brief";
  description = "Weekday morning finance brief — portfolio + benchmarks";
  schedule = "Mon..Fri 07:30:00";
  script = ''
        MODEL="''${LLM_MODEL:-qwen2.5:14b}"
        GHOSTFOLIO_URL="''${GHOSTFOLIO_URL:-http://127.0.0.1:3333}"
        TOKEN_FILE="/var/lib/agents/ghostfolio-token"

        # --------------------------------------------------------------
        # 1. Portfolio snapshot (optional — script still runs without token)
        # --------------------------------------------------------------
        PORTFOLIO="{}"
        if [ -r "$TOKEN_FILE" ]; then
          GF_TOKEN="$(cat "$TOKEN_FILE")"
          PORTFOLIO=$(curl -sf -H "Authorization: Bearer $GF_TOKEN" \
            "$GHOSTFOLIO_URL/api/v1/portfolio/details?range=1d" || echo '{}')
        fi

        # --------------------------------------------------------------
        # 2. Public benchmark quotes.
        # --------------------------------------------------------------
        # Yahoo Finance v7 quotes endpoint (unofficial but stable for years).
        YAHOO="^GSPC,^STOXX50E,FTSEMIB.MI,GC=F,CL=F,EURUSD=X,BTC-USD,ETH-USD"

        BENCH=$(curl -sf \
          -H 'accept: application/json' \
          -H 'user-agent: Mozilla/5.0 hacker-box-agent' \
          "https://query1.finance.yahoo.com/v7/finance/quote?symbols=$YAHOO" \
          | jq -c '.quoteResponse.result[] | {sym: .symbol, price: .regularMarketPrice, chg_pct: .regularMarketChangePercent}' \
          || echo "")

        # CoinGecko fallback / cross-check for crypto.
        CRYPTO=$(curl -sf \
          "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=eur&include_24hr_change=true" \
          || echo '{}')

        # ECB reference rate (fixings, published ~16:00 CET; morning uses previous close).
        FX=$(curl -sf "https://api.frankfurter.app/latest?from=EUR&to=USD,GBP,CHF,JPY" || echo '{}')

        # --------------------------------------------------------------
        # 3. Compose the prompt.
        # --------------------------------------------------------------
        PROMPT=$(cat <<'EOF'
    You are a personal finance analyst. Below you have:
      (a) a JSON snapshot of the operator's portfolio (positions, P&L today);
      (b) benchmark quotes (indices, commodities, FX, crypto).

    Write a concise morning brief in Italian, structured as:

    ## Snapshot mercati
    Bullet list (5-8 items) with symbol → price → daily % change, sorted by
    absolute % move.

    ## Portafoglio
    2-3 sentences on how the portfolio moved vs the benchmarks. Name winners
    and losers. If the portfolio JSON is empty, say "portafoglio non
    disponibile — configurare token Ghostfolio".

    ## Watchlist
    Three concrete things to watch today, each explained in one sentence.

    ## Contesto
    One paragraph tying today's numbers to a broader theme (earnings,
    central bank calendar, macro data).

    No investment advice, no price predictions, no hype. Facts + framing.
    EOF
        )

        USER_INPUT=$(jq -n \
          --argjson portfolio "$PORTFOLIO" \
          --argjson bench "$(printf '[%s]' "$(printf '%s' "$BENCH" | paste -sd, -)")" \
          --argjson crypto "$CRYPTO" \
          --argjson fx "$FX" \
          '{portfolio:$portfolio, benchmarks:$bench, crypto:$crypto, fx:$fx}')

        PAYLOAD=$(jq -n \
          --arg model "$MODEL" \
          --arg system "$PROMPT" \
          --arg user "$USER_INPUT" \
          '{model:$model, stream:false, system:$system, prompt:$user,
            options:{temperature:0.2, num_ctx:16384}}')

        BRIEF=$(curl -sf "$OLLAMA_URL/api/generate" \
          -H 'content-type: application/json' -d "$PAYLOAD" \
          | jq -r '.response')

        if [ -z "$BRIEF" ]; then
          echo "empty brief — abort"
          exit 1
        fi

        TODAY=$(date +%Y-%m-%d)
        printf '%s' "$BRIEF" > "$STATE_DIR/$TODAY-brief.md"

        curl -sf -X POST "$NTFY_URL/finance" \
          -H "Title: Finance brief — $TODAY" \
          -H "Priority: default" \
          -H "Tags: chart_with_upwards_trend" \
          -H "Markdown: yes" \
          ''${NTFY_TOKEN:+ -H "Authorization: Bearer $NTFY_TOKEN"} \
          --data-binary "$BRIEF"
  '';
}
