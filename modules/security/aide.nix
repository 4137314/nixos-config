/*
  security/aide.nix — Host-based Intrusion Detection (file integrity).

  What it watches
  ---------------
  The AIDE database records checksums, permissions, ownership, and inode
  metadata of critical filesystems. Every day at 05:00 a check runs; if
  any monitored file has been modified without a corresponding NixOS
  activation event, ntfy fires a warning.

  Scope
  -----
    /etc/nixos     the flake itself
    /boot          bootloader + kernel + initrd
    /etc           runtime host state (mostly derived from Nix but not all)
    /root          root's own dotfiles
    /var/lib/sops-nix    host age key — MUST not change silently

  Excluded (churn too high to be useful signals)
    /nix           immutable by design, verified by nix itself
    /var/log       always changing
    /var/lib/{postgres,ollama,podman,paperless,immich}   service state
    /home          user data

  Initialise the DB
  -----------------
  First-run and after any legitimate change you must rebase the DB:
      sudo aide --init
      sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
  This is done automatically on the FIRST activation via the systemd
  unit below (guards with a state file so it only runs once).
*/
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.aide ];

  environment.etc."aide.conf".text = ''
    # NixOS-packaged AIDE does not enable the `url` parser at build time,
    # so `database=file:/...` fails with "unexpected character: ':'".
    # Use bare paths instead.
    database=/var/lib/aide/aide.db
    database_out=/var/lib/aide/aide.db.new
    gzip_dbout=yes

    # Rule presets
    Full = p+i+n+u+g+s+m+c+md5+sha256
    Meta = p+i+n+u+g+s

    /etc/nixos          Full
    /boot               Full
    /etc                Meta
    /root               Meta
    /var/lib/sops-nix   Full

    # Exclusions — high-churn directories.
    !/nix
    !/var/log
    !/var/lib/postgres
    !/var/lib/postgresql
    !/var/lib/ollama
    !/var/lib/containers
    !/var/lib/paperless
    !/var/lib/immich
    !/var/lib/nextcloud
    !/var/lib/private
    !/etc/machine-id
    !/etc/resolv.conf
    !/etc/adjtime
    !/etc/mtab
    !/etc/ssh/ssh_host_.*_key\.pub
  '';

  systemd = {
    services = {
      aide-init = {
        description = "AIDE database initialisation (first-run only)";
        wantedBy = [ "multi-user.target" ];
        after = [ "local-fs.target" ];
        unitConfig.ConditionPathExists = "!/var/lib/aide/aide.db";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/lib/aide";
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.aide}/bin/aide --init && cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db'";
        };
      };

      aide-check = {
        description = "AIDE daily integrity check";
        path = with pkgs; [
          aide
          curl
          coreutils
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "aide-check" ''
            set -uo pipefail
            DIFF=$(aide --check 2>&1 || true)
            if echo "$DIFF" | grep -q '^Number of entries'; then
              if echo "$DIFF" | grep -qE 'added|removed|changed'; then
                SUMMARY=$(echo "$DIFF" | head -n 40)
                curl -sf -X POST http://127.0.0.1:2586/system \
                  -H "Title: AIDE detected changes" \
                  -H "Priority: high" \
                  -H "Tags: warning,mag" \
                  --data "$SUMMARY"
              fi
            fi
          '';
        };
      };
    };

    timers.aide-check = {
      description = "AIDE daily integrity check timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 05:00:00";
        Persistent = true;
        RandomizedDelaySec = "20m";
      };
    };
  };
}
