/*
  agents/lib.nix — Reusable builder for autonomous LLM pipelines.

  Not a NixOS module — a plain Nix helper. Consume from an agent file:

    { pkgs, lib, ... }:
    let mkAgent = (import ../lib.nix { inherit pkgs lib; }).mkAgent;
    in mkAgent { name = "…"; ... }

  Every agent produced by `mkAgent` gets:
    * a dedicated unprivileged user `agent-<name>` (member of `obs-bus`
      so it can publish to the observatory event bus),
    * state directory /var/lib/agents/<name>/  (0750, RW only for its user),
    * a sandboxed systemd unit (ProtectSystem=strict, PrivateTmp, …),
    * env: OLLAMA_URL, NTFY_URL, LOKI_URL, STATE_DIR, HOSTNAME,
    * PATH pre-loaded with curl, jq, gawk, gnused, and `obs-event`,
    * **auto-emission of lifecycle events** on the observatory bus:
        run_start        at the top of the script (correlation_id captured)
        run_completed    on clean exit  (rc == 0)
        run_failed       on non-zero exit (payload includes exit_code)

  The correlation_id is `agent-<name>-<epoch_ns>` and is preserved for
  the whole run, so `obs-event chain <id>` walks the workflow (and
  brains / metrics can group per-run).
*/
{ pkgs, lib }:
let
  # Pull `obs-event` from the observatory lib so ALL agents publish to
  # the same JSONL bus with the same schema.
  inherit (import ./observatory/lib.nix { inherit pkgs; }) obs-event;

  agentUser = name: "agent-${name}";

  mkAgent =
    {
      name,
      description,
      schedule,
      script,
      extraPackages ? [ ],
      extraServiceConfig ? { },
      persistent ? true,
    }:
    let
      user = agentUser name;

      runner = pkgs.writeShellApplication {
        name = "agent-${name}";
        runtimeInputs =
          with pkgs;
          [
            curl
            jq
            coreutils
            gawk
            gnused
            obs-event
          ]
          ++ extraPackages;
        text = ''
          set -uo pipefail
          umask 077

          export STATE_DIR="/var/lib/agents/${name}"
          mkdir -p "$STATE_DIR"

          export OLLAMA_URL="''${OLLAMA_URL:-http://127.0.0.1:11434}"
          export NTFY_URL="''${NTFY_URL:-http://127.0.0.1:2586}"
          export LOKI_URL="''${LOKI_URL:-http://127.0.0.1:3100}"
          export HOSTNAME="''${HOSTNAME:-nixos-hacker-box}"

          if [ -r /var/lib/agents/ntfy-token ]; then
            NTFY_TOKEN="$(cat /var/lib/agents/ntfy-token)"
            export NTFY_TOKEN
          fi

          # ── Observatory bus integration ─────────────────────────────
          # Per-run correlation id so downstream agents (or `obs-event
          # chain`) can walk the whole workflow later.
          __CORR="agent-${name}-$(date +%s%N)"
          export OBS_CORRELATION_ID="$__CORR"

          __emit_exit() {
            local rc=$?
            if [ "$rc" -eq 0 ]; then
              obs-event publish "agent-${name}" run_completed '{}' \
                --correlation="$__CORR" >/dev/null 2>&1 || true
            else
              obs-event publish "agent-${name}" run_failed \
                "$(jq -cn --argjson c "$rc" '{exit_code:$c}')" \
                --correlation="$__CORR" >/dev/null 2>&1 || true
            fi
          }
          trap __emit_exit EXIT

          obs-event publish "agent-${name}" run_start '{}' \
            --correlation="$__CORR" >/dev/null 2>&1 || true

          echo "agent[${name}] starting at $(date -Iseconds)"

          # ── User-supplied pipeline body ─────────────────────────────
          ${script}

          echo "agent[${name}] done at $(date -Iseconds)"
        '';
      };
    in
    {
      users = {
        users.${user} = {
          isSystemUser = true;
          group = user;
          # Membership of `obs-bus` grants write access to
          # /var/lib/observatory/events.jsonl (see observatory/default.nix).
          extraGroups = [ "obs-bus" ];
          home = "/var/lib/agents/${name}";
          createHome = false;
        };
        groups.${user} = { };
      };

      systemd = {
        tmpfiles.rules = [
          "d /var/lib/agents/${name} 0750 ${user} ${user} -"
        ];

        services."agent-${name}" = lib.mkMerge [
          {
            inherit description;
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            serviceConfig = {
              Type = "oneshot";
              User = user;
              Group = user;
              ExecStart = "${runner}/bin/agent-${name}";
              NoNewPrivileges = true;
              PrivateTmp = true;
              PrivateDevices = true;
              ProtectSystem = "strict";
              ProtectHome = true;
              # Own state dir + observatory bus (append via `obs-event`).
              ReadWritePaths = [
                "/var/lib/agents/${name}"
                "/var/lib/observatory/events.jsonl"
                "/var/lib/observatory/events.jsonl.lock"
              ];
              ProtectKernelTunables = true;
              ProtectKernelModules = true;
              ProtectControlGroups = true;
              LockPersonality = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              SystemCallArchitectures = "native";
            };
          }
          extraServiceConfig
        ];

        timers."agent-${name}" = {
          description = "${description} (timer)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = schedule;
            Persistent = persistent;
            RandomizedDelaySec = "3m";
            Unit = "agent-${name}.service";
          };
        };
      };
    };
in
{
  inherit mkAgent;
}
