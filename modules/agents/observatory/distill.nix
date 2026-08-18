/*
  agents/observatory/distill.nix — CPU distillation playground (opt-in).

  Full fine-tuning is not viable on the current AMD Polaris GPU (8 GB VRAM
  is not enough headroom for gradients even for a 3B model). This module
  exposes an opt-in `obs-distill` CLI that:
    * `prepare` — builds a JSONL training dataset from git commits + agent
                  reports, ready to feed to llama.cpp finetune tools.
    * `run`     — refuses to start unless `llama-finetune` is on PATH and
                  points the user at the RAG-based alternative that is
                  already wired (obs-rag), which is functionally
                  equivalent for personalisation on this hardware.

  No systemd unit is declared — this is a manual `sudo obs-distill …`.
*/
{ pkgs, ... }:
let
  inherit (import ./lib.nix { inherit pkgs; }) outputDir;

  obs-distill = pkgs.writeShellApplication {
    name = "obs-distill";
    runtimeInputs = with pkgs; [
      git
      findutils
      coreutils
      jq
    ];
    text = ''
      set -uo pipefail
      dir="${outputDir}/distill"
      dataset="$dir/dataset.jsonl"
      mkdir -p "$dir"

      case "''${1:-}" in
        prepare)
          {
            find /home/main -maxdepth 5 -type d -name .git 2>/dev/null \
            | while read -r g; do
                repo="$(dirname "$g")"
                git -C "$repo" log --pretty=format:'%H%x1f%s%x1f%b%x1e' \
                                   --since='1 year ago' 2>/dev/null \
                | tr '\x1e' '\n' \
                | while IFS=$'\x1f' read -r sha subject body; do
                    [ -z "$sha" ] && continue
                    jq -cn --arg s "$subject" --arg b "$body" \
                      '{instruction:"Explain this commit.", input:$s, output:$b}'
                  done
              done

            find ${outputDir} -type f -name '*.md' 2>/dev/null \
            | while read -r f; do
                jq -cn --arg f "$f" --arg c "$(head -c 4000 "$f")" \
                  '{instruction:"Summarise this agent report.", input:$f, output:$c}'
              done
          } > "$dataset"
          echo "obs-distill: wrote $(wc -l < "$dataset") examples to $dataset"
          ;;

        run)
          if ! command -v llama-finetune >/dev/null 2>&1; then
            {
              echo "obs-distill: llama-finetune not on PATH."
              echo
              echo "On-Polaris fine-tuning is CPU-only and takes many hours."
              echo "If you really want to run this, add \`pkgs.llama-cpp\` to"
              echo "\`environment.systemPackages\` in configuration.nix, then"
              echo "rebuild. Even then, expect ~12h for a 1B parameter model."
              echo
              echo "Better long-term path: keep using RAG (obs-rag) — it"
              echo "retrieves your personal data at inference time and needs"
              echo "no training."
            } >&2
            exit 3
          fi
          echo "obs-distill: would run llama-finetune on $dataset — TODO"
          ;;

        *)
          echo "usage: obs-distill {prepare|run}" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  environment.systemPackages = [ obs-distill ];
}
