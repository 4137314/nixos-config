/*
  agents/observatory/rag.nix — Query CLI over the Qdrant `observatory`
  collection. See `indexer.nix` for how the collection is populated.

  Usage
  -----
    obs-rag query "TEXT" [TOP_K]
    obs-rag stats
*/
{ pkgs, ... }:
let
  ollamaUrl = "http://127.0.0.1:11434";
  qdrantUrl = "http://127.0.0.1:6333";
  qdrantCol = "observatory";
  embedModel = "nomic-embed-text";

  obs-rag = pkgs.writeShellApplication {
    name = "obs-rag";
    runtimeInputs = with pkgs; [
      curl
      jq
    ];
    text = ''
      set -euo pipefail
      cmd=''${1:-query}
      case "$cmd" in
        query)
          shift
          text=''${1:?query text required}
          top=''${2:-5}
          embedding=$(jq -n --arg m "${embedModel}" --arg p "$text" \
                        '{model:$m, prompt:$p}' \
                      | curl -sfN --max-time 30 -X POST \
                          "${ollamaUrl}/api/embeddings" \
                          -H "Content-Type: application/json" --data @- \
                      | jq -c '.embedding')
          if [ -z "$embedding" ] || [ "$embedding" = "null" ]; then
            echo "obs-rag: embedding failed (is ollama up?)" >&2
            exit 3
          fi
          jq -n --argjson v "$embedding" --argjson k "$top" \
            '{vector:$v, limit:$k, with_payload:true}' \
            | curl -sfN --max-time 15 -X POST \
                "${qdrantUrl}/collections/${qdrantCol}/points/search" \
                -H "Content-Type: application/json" --data @- \
            | jq -r '.result[] | "── score \(.score | . * 1000 | round / 1000)  source=\(.payload.source)\n\(.payload.text)\n"'
          ;;
        stats)
          curl -sf "${qdrantUrl}/collections/${qdrantCol}" \
            | jq '.result | {points: .points_count, indexed: .indexed_vectors_count, status}'
          ;;
        *)
          echo "usage: obs-rag {query TEXT [TOP_K] | stats}" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  environment.systemPackages = [ obs-rag ];
}
