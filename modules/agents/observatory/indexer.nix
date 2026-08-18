/*
  agents/observatory/indexer.nix — Rebuilds the Qdrant `observatory`
  collection from three sources every 4 h:

    1. /etc/nixos               — every .nix file (config knowledge)
    2. /var/lib/observatory     — every .md  report (agent history)
    3. last 24h journalctl warnings (recent state)

  Each source is chunked (~1200 chars, no overlap) and embedded with
  `nomic-embed-text` via Ollama. The collection is recreated from
  scratch on every run — the index is small (~a few thousand chunks)
  so re-embedding is minutes, not hours, and it side-steps state
  drift from partial updates.
*/
{ pkgs, ... }:
let
  inherit (import ./lib.nix { inherit pkgs; }) outputDir hardenedService;

  ollamaUrl = "http://127.0.0.1:11434";
  qdrantUrl = "http://127.0.0.1:6333";
  qdrantCol = "observatory";
  embedModel = "nomic-embed-text";

  obs-indexer = pkgs.writeShellApplication {
    name = "obs-indexer";
    runtimeInputs = with pkgs; [
      curl
      jq
      findutils
      coreutils
      gawk
      systemd
    ];
    text = ''
      set -uo pipefail

      # Recreate collection (nomic-embed-text → 768-dim vectors).
      curl -sf --max-time 5 -X DELETE \
        "${qdrantUrl}/collections/${qdrantCol}" >/dev/null || true
      curl -sf --max-time 10 -X PUT \
          "${qdrantUrl}/collections/${qdrantCol}" \
          -H "Content-Type: application/json" \
          --data '{"vectors":{"size":768,"distance":"Cosine"}}' >/dev/null \
        || { echo "obs-indexer: Qdrant unreachable" >&2; exit 1; }

      id=0
      total=0
      index_stdin() {
        local source=$1 path=$2
        awk -v RS= -v ORS= '{gsub(/\r/,""); print}' \
        | fold -s -w1200 \
        | while IFS= read -r chunk; do
            [ -z "$(echo "$chunk" | tr -d '[:space:]')" ] && continue
            emb=$(jq -n --arg m "${embedModel}" --arg p "$chunk" \
                    '{model:$m, prompt:$p}' \
                  | curl -sf --max-time 30 -X POST \
                      "${ollamaUrl}/api/embeddings" \
                      -H "Content-Type: application/json" --data @- \
                  | jq -c '.embedding')
            [ -z "$emb" ] || [ "$emb" = "null" ] && continue
            point=$(jq -cn --argjson id "$id" --argjson v "$emb" \
                          --arg s "$source" --arg p "$path" --arg t "$chunk" \
                     '{points:[{id:$id, vector:$v,
                                payload:{source:$s, path:$p, text:$t}}]}')
            curl -sf --max-time 10 -X PUT \
              "${qdrantUrl}/collections/${qdrantCol}/points" \
              -H "Content-Type: application/json" --data "$point" >/dev/null || true
            id=$((id + 1))
            total=$((total + 1))
          done
      }

      # SC2094 is a false positive: `index_stdin` writes to Qdrant, not $f.
      # shellcheck disable=SC2094
      while IFS= read -r f; do
        index_stdin "flake" "$f" < "$f"
      done < <(find /etc/nixos -type f -name '*.nix' 2>/dev/null)

      # shellcheck disable=SC2094
      while IFS= read -r f; do
        index_stdin "report" "$f" < "$f"
      done < <(find ${outputDir} -type f -name '*.md' 2>/dev/null)

      journalctl --since='24 hours ago' -p warning --no-pager -q 2>/dev/null \
        | head -800 \
        | index_stdin "journal" "last-24h"

      echo "obs-indexer: indexed $total chunks"
    '';
  };
in
{
  environment.systemPackages = [ obs-indexer ];

  systemd = {
    services.obs-indexer = {
      description = "Observatory — RAG (re-)indexer";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = hardenedService // {
        ExecStart = "${obs-indexer}/bin/obs-indexer";
      };
    };
    timers.obs-indexer = {
      description = "Observatory indexer — every 4h";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 02/4:15:00";
        Persistent = true;
        RandomizedDelaySec = "10m";
      };
    };
  };
}
