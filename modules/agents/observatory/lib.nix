/*
  agents/observatory/lib.nix — Shared CLI helpers and hardening.

  Every observatory sub-module imports from this file so schema
  changes, ntfy plumbing, and systemd hardening evolve in one place.

  Exports
  -------
    obs-ask          Ollama /api/generate wrapper (stdin → stdout).
    obs-ntfy         ntfy `system` topic push (silent if no token).
    obs-event        Enriched event bus (see schema below).
    hardenedService  systemd `serviceConfig` block used by every oneshot.
    outputDir        /var/lib/observatory  — root of on-disk state.

  Event bus schema (v2)
  ---------------------
    {
      "id"             : "<agent>-<epoch_ns>-<rand>",  // unique
      "ts"             : "<ISO8601 UTC>",
      "agent"          : "obs-<name>",
      "type"           : "<snake_case>",
      "payload"        : <any JSON>,
      "correlation_id" : "<id>|null",                  // groups a workflow
      "cause_id"       : "<id>|null"                   // parent event
    }

  Every `obs-event publish` prints the generated `id` on stdout so the
  caller can capture it and pass `--cause=$id` in the next publish
  down the chain. Correlation IDs are inherited across an agent's own
  run — see `passive.nix` and `active.nix` for the pattern.

  Query surface
  -------------
    obs-event tail  [N]
    obs-event since ISO8601
    obs-event query [--type=T] [--agent=A] [--since=ISO] [--limit=N]
    obs-event chain ID          // walks correlation_id + cause_id
*/
{ pkgs }:
let
  outputDir = "/var/lib/observatory";
  eventBus = "${outputDir}/events.jsonl";
  ollamaUrl = "http://127.0.0.1:11434";
  ntfyUrl = "http://127.0.0.1:2586/system";
  ntfyTokenFile = "/etc/ntfy/token";
in
rec {
  inherit outputDir;

  obs-ask = pkgs.writeShellApplication {
    name = "obs-ask";
    runtimeInputs = with pkgs; [
      curl
      jq
    ];
    text = ''
      set -euo pipefail
      model=''${1:?model required}
      system=''${2:?system prompt required}
      user=$(cat)
      jq -n --arg m "$model" --arg s "$system" --arg u "$user" '{
        model:$m, system:$s, prompt:$u, stream:false,
        options:{temperature:0.2, num_predict:512}
      }' \
        | curl -sfN --max-time 120 -X POST "${ollamaUrl}/api/generate" \
              -H "Content-Type: application/json" --data @- \
        | jq -r '.response // ""' 2>/dev/null || echo ""
    '';
  };

  obs-ntfy = pkgs.writeShellApplication {
    name = "obs-ntfy";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      set -euo pipefail
      title=''${1:?title required}
      prio=''${2:?priority required}
      tags=''${3:?tags required}
      body=''${4:?body required}
      [ -r "${ntfyTokenFile}" ] || exit 0
      token=$(cat "${ntfyTokenFile}")
      curl -sf --max-time 10 -X POST "${ntfyUrl}" \
        -H "Authorization: Bearer $token" \
        -H "Title: $title" \
        -H "Priority: $prio" \
        -H "Tags: $tags" \
        --data "$body" >/dev/null || true
    '';
  };

  obs-event = pkgs.writeShellApplication {
    name = "obs-event";
    runtimeInputs = with pkgs; [
      jq
      coreutils
      util-linux
    ];
    text = ''
      set -euo pipefail
      bus=${eventBus}

      # Generate a unique event ID:  <agent>-<epoch_ns>-<rand_hex>
      gen_id() {
        local a=$1
        printf '%s-%s-%04x' "$a" "$(date +%s%N)" $((RANDOM % 65536))
      }

      case "''${1:-}" in
        publish)
          agent=''${2:?agent required}
          etype=''${3:?type required}
          payload=''${4:-'{}'}
          shift 4 || true
          cause=null
          corr=null
          while [ $# -gt 0 ]; do
            case "$1" in
              --cause=*)       cause=$(jq -Rn --arg s "''${1#*=}" '$s') ;;
              --correlation=*) corr=$(jq -Rn --arg s "''${1#*=}" '$s') ;;
              *) echo "obs-event publish: unknown flag $1" >&2; exit 2 ;;
            esac
            shift
          done
          id=$(gen_id "$agent")
          ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
          # Wrap non-JSON payload as a string, so `.payload` is always valid JSON.
          if ! echo "$payload" | jq -e . >/dev/null 2>&1; then
            payload=$(jq -Rn --arg s "$payload" '$s')
          fi
          record=$(jq -cn \
            --arg id "$id" --arg ts "$ts" --arg a "$agent" --arg t "$etype" \
            --argjson p "$payload" \
            --argjson cause "$cause" \
            --argjson corr "$corr" \
            '{id:$id, ts:$ts, agent:$a, type:$t, payload:$p,
              correlation_id:$corr, cause_id:$cause}')
          ( flock -x 9; echo "$record" >> "$bus" ) 9>>"$bus.lock"
          # Echo the fresh ID so shell scripts can capture and chain.
          echo "$id"
          ;;

        tail)
          n=''${2:-50}
          [ -f "$bus" ] || exit 0
          tail -n "$n" "$bus"
          ;;

        since)
          cutoff=''${2:?ISO8601 cutoff required}
          [ -f "$bus" ] || exit 0
          jq -c --arg c "$cutoff" 'select(.ts >= $c)' "$bus"
          ;;

        query)
          shift
          f_type='.'; f_agent='.'; f_since='.'; limit=100
          while [ $# -gt 0 ]; do
            case "$1" in
              --type=*)  f_type="select(.type == \"''${1#*=}\")" ;;
              --agent=*) f_agent="select(.agent == \"''${1#*=}\")" ;;
              --since=*) f_since="select(.ts >= \"''${1#*=}\")" ;;
              --limit=*) limit="''${1#*=}" ;;
              *) echo "obs-event query: unknown flag $1" >&2; exit 2 ;;
            esac
            shift
          done
          [ -f "$bus" ] || exit 0
          jq -c "$f_type | $f_agent | $f_since" "$bus" | tail -n "$limit"
          ;;

        chain)
          id=''${2:?event id required}
          [ -f "$bus" ] || exit 0
          # Correlation ID of the anchor event (fallback to its own id).
          corr=$(jq -r --arg id "$id" \
                   'select(.id == $id) | .correlation_id // .id' \
                   "$bus" | head -1)
          if [ -z "$corr" ] || [ "$corr" = "null" ]; then
            echo "obs-event chain: id not found" >&2
            exit 3
          fi
          # Print every event with the same correlation_id OR the id itself.
          jq -c --arg c "$corr" \
            'select(.correlation_id == $c or .id == $c)' "$bus"
          ;;

        *)
          {
            echo "Usage:"
            echo "  obs-event publish AGENT TYPE PAYLOAD [--cause=ID] [--correlation=ID]"
            echo "      Appends an event to the bus. Prints the new ID on stdout."
            echo "  obs-event tail [N]                            Last N events."
            echo "  obs-event since ISO8601                       Events with ts >= cutoff."
            echo "  obs-event query [--type=T] [--agent=A] [--since=ISO] [--limit=N]"
            echo "      Filtered feed."
            echo "  obs-event chain ID                            Walk the causal chain."
          } >&2
          exit 2
          ;;
      esac
    '';
  };

  hardenedService = {
    Type = "oneshot";
    User = "root";
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = "read-only";
    ReadWritePaths = [ outputDir ];
    PrivateTmp = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    RestrictNamespaces = true;
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
  };
}
