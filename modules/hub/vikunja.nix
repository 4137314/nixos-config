/*
  hub/vikunja.nix — Self-hosted task/project management (Todoist-like).

  Features
  --------
  Kanban boards, Gantt, list, calendar views. Native REST API + iOS/Android
  apps. Reminders push to email or (via n8n bridge) to ntfy.

  Storage
  -------
  SQLite in /var/lib/vikunja/vikunja.db. State + attachments both there.

  Access
  ------
  http://127.0.0.1:3456 direct, https://tasks.nixos-hacker-box behind Caddy.

  Secrets
  -------
  Vikunja needs `service.secret` (the signing key for JWT sessions +
  password reset tokens). The key MUST NOT live in the Nix store
  (world-readable via /nix/store), so it comes from a systemd env file
  loaded before the service drops privileges. `service.jwtsecret` is
  the deprecated older name — do not use it, upstream will remove it.

  The `vikunja-secret-init` oneshot below generates the env file on
  first boot with a random `VIKUNJA_SERVICE_SECRET`. It also
  transparently upgrades a legacy env file that only has
  `VIKUNJA_SERVICE_JWTSECRET` from a previous configuration.

  To rotate the key:  sudo rm /etc/vikunja/env && sudo systemctl restart vikunja

  First-run
  ---------
  Just wait for `vikunja.service` to become active, then open the URL
  and create an account. Registrations are open on first boot; disable
  via `settings.service.enableregistration = false` after your account.
*/
{ pkgs, ... }:
{
  services.vikunja = {
    enable = true;
    frontendScheme = "https";
    frontendHostname = "tasks.nixos-hacker-box";
    port = 3456;

    # Secret comes from this file, never the Nix store.
    environmentFiles = [ "/etc/vikunja/env" ];

    settings = {
      service = {
        # `publicurl` is set automatically by the NixOS 25.11 module from
        # `frontendScheme` + `frontendHostname` above — do NOT re-declare
        # it here (option-merge conflict). It's used by Vikunja for
        # absolute link generation and CORS pre-flight.
        enableregistration = true; # flip to false after your account
        timezone = "Europe/Rome";
      };

      files = {
        basepath = "/var/lib/vikunja/files";
        maxsize = "50MB";
      };

      metrics.enabled = true; # scraped by Prometheus if scrape config added
    };
  };

  # ---------------------------------------------------------------------------
  # Auto-provision `service.secret` on first boot so vikunja.service starts
  # cleanly on a fresh install. Also migrates legacy env files that used the
  # deprecated `VIKUNJA_SERVICE_JWTSECRET` name.
  #
  # DynamicUser is used by the upstream module → `vikunja` is not a static
  # POSIX account. The directory must remain traversable because Vikunja reads
  # the public Nix-generated `/etc/vikunja/config.yaml` after dropping
  # privileges. EnvironmentFile= is read by systemd before that drop, so the
  # secret itself remains root:root 0400 and never enters the Nix store.
  # ---------------------------------------------------------------------------
  systemd.services = {
    # Keep a broken configuration from hammering both Vikunja and its secret
    # dependency; changing the main unit also guarantees a restart on switch.
    vikunja.serviceConfig.RestartSec = "5s";

    vikunja-secret-init = {
      description = "Generate/migrate Vikunja service secret on first boot";
      wantedBy = [ "vikunja.service" ];
      before = [ "vikunja.service" ];
      path = with pkgs; [
        openssl
        coreutils
        gnugrep
      ];
      # NB: no `RemainAfterExit = true` — we want ExecStart to re-run
      # every time `vikunja.service` is (re)started, so a deleted env
      # file gets regenerated on the next `systemctl restart vikunja`.
      # The script is idempotent (skips if the env is well-formed).
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail
        install -d -m 0755 -o root -g root /etc/vikunja

        needs_write=0
        if [ ! -s /etc/vikunja/env ]; then
          needs_write=1
        elif ! grep -q '^VIKUNJA_SERVICE_SECRET=' /etc/vikunja/env; then
          # Legacy file with only JWTSECRET — upstream deprecated it.
          # Regenerate with the current variable name.
          needs_write=1
        fi

        if [ "$needs_write" -eq 1 ]; then
          umask 077
          secret=$(openssl rand -hex 32)
          printf 'VIKUNJA_SERVICE_SECRET=%s\n' "$secret" > /etc/vikunja/env
          chmod 0400 /etc/vikunja/env
        fi
      '';
    };
  };
}
