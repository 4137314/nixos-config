/*
  agents/lib.nix — Reusable builder for autonomous LLM pipelines.

  This file is a plain Nix helper (NOT a NixOS module). Import it from
  agent modules like:

    { pkgs, lib, ... }:
    let mkAgent = (import ./lib.nix { inherit pkgs lib; }).mkAgent;
    in mkAgent { name = "…"; ... }

  Returns a NixOS-module-shaped attrset with systemd service + timer +
  system user pre-configured. Every agent gets:
    - dedicated unprivileged user `agent-<name>`
    - state directory /var/lib/agents/<name> (0750, RW only for its user)
    - sandboxed systemd unit (ProtectSystem=strict, PrivateTmp, …)
    - env vars: OLLAMA_URL, NTFY_URL, LOKI_URL, STATE_DIR, HOSTNAME
    - PATH pre-loaded with curl, jq, gawk, gnused
*/
{ pkgs, lib }:
let
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
          ]
          ++ extraPackages;
        text = ''
          set -euo pipefail
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

          echo "agent[${name}] starting at $(date -Iseconds)"

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
              ReadWritePaths = [ "/var/lib/agents/${name}" ];
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
