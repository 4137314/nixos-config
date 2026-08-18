/*
  backup/verify.nix — Weekly restic health check + spot restore.

  Schrödinger's backup: if you never verify it, it doesn't exist. Every
  Sunday at 04:00 this unit:

    1. `restic check --read-data-subset=2%` — verifies random 2% of blobs.
    2. `restic restore latest --target /tmp/verify --include /etc/nixos`
       — pulls the flake back down.
    3. `diff -qr /tmp/verify/etc/nixos /etc/nixos | grep -v result` —
       if anything mismatches (ignoring build artefacts), we push a
       critical ntfy.
    4. Cleanup /tmp/verify.

  Failure exit codes bubble to systemd + journald + Prometheus (via the
  systemd exporter) so the existing ServiceDown alert fires.

  Prerequisites
  -------------
    /etc/restic/repo-password       symmetric key (0400 root)
    /etc/restic/env                 B2_ACCOUNT_ID + B2_ACCOUNT_KEY (0400 root)
    /etc/ntfy/token                 bearer token for the local ntfy admin (0400 root)

  Repository URL is kept in a single place (`backup/restic.nix`) and passed
  in via a NixOS build-time substitution; do not duplicate it here.
*/
{ config, pkgs, ... }:
let
  # Single source of truth for the repository URL — matches restic.nix.
  resticRepository = config.services.restic.backups.offsite.repository;
in
{
  systemd = {
    services.restic-verify = {
      description = "Weekly restic integrity check + spot restore";
      after = [
        "network-online.target"
        "restic-backups-offsite.service"
      ];
      wants = [ "network-online.target" ];

      path = with pkgs; [
        restic
        diffutils
        coreutils
        curl
      ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "root";
        ExecStart = pkgs.writeShellScript "restic-verify" ''
          set -euo pipefail

          # ------------------------------------------------------------------
          # Restic environment — reuse the same secrets as the daily backup.
          # ------------------------------------------------------------------
          export RESTIC_REPOSITORY="${resticRepository}"
          export RESTIC_PASSWORD_FILE=/etc/restic/repo-password
          # `set -a` exports every variable the env file defines (B2 keys).
          set -a
          # shellcheck disable=SC1091
          source /etc/restic/env
          set +a

          # ------------------------------------------------------------------
          # ntfy authentication — bearer token required (deny-all default).
          # ------------------------------------------------------------------
          NTFY_TOKEN=$(cat /etc/ntfy/token)
          ntfy() {
            local title=$1 priority=$2 tag=$3 body=$4
            curl -sf -X POST http://127.0.0.1:2586/backup \
              -H "Authorization: Bearer $NTFY_TOKEN" \
              -H "Title: $title" \
              -H "Priority: $priority" \
              -H "Tags: $tag" \
              --data "$body" \
              >/dev/null
          }

          WORK=$(mktemp -d /tmp/restic-verify.XXXXXX)
          trap 'rm -rf "$WORK"' EXIT

          echo "[verify] restic check (2% data subset)…"
          restic check --read-data-subset=2%

          echo "[verify] restore /etc/nixos from latest snapshot…"
          restic restore latest --target "$WORK" --include /etc/nixos

          echo "[verify] diff against live tree…"
          if diff -qr "$WORK/etc/nixos" /etc/nixos \
               | grep -Ev 'result$|result-|/\.direnv/|/\.git/' \
               | grep -q .; then
            echo "[verify] MISMATCH detected"
            ntfy "Restic verify FAILED" urgent rotating_light \
              "Diff between latest restic snapshot and live /etc/nixos. Investigate."
            exit 1
          fi

          echo "[verify] OK"
          ntfy "Restic verify OK" low white_check_mark \
            "Weekly restore drill passed. Snapshot is complete and readable."
        '';
      };
    };

    timers.restic-verify = {
      description = "Weekly restic verify (Sunday 04:00)";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Sun *-*-* 04:00:00";
        Persistent = true;
        RandomizedDelaySec = "15m";
      };
    };

    tmpfiles.rules = [
      "d /etc/ntfy 0700 root root -"
    ];
  };
}
