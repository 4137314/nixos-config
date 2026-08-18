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
  `JWTSecret` MUST NOT live in the Nix store (world-readable). It is
  supplied via a systemd env file (`environmentFiles`) that provides
  `VIKUNJA_SERVICE_JWTSECRET=<random 32-byte hex>` to the daemon.

  The `vikunja-secret-init` oneshot below generates that file on first
  boot if it doesn't already exist, so the service starts cleanly on a
  fresh install without any manual step. To rotate the key later:
    sudo rm /etc/vikunja/env && sudo systemctl restart vikunja

  First-run
  ---------
  Just wait for `vikunja.service` to become active, then open the URL
  and create an account. Registrations are open on first boot; disable
  via `settings.service.enableregistration = false` after your account.
  Optional: connect the iOS / Android app pointing at the same URL.
*/
{ pkgs, ... }:
{
  services.vikunja = {
    enable = true;
    frontendScheme = "https";
    frontendHostname = "tasks.nixos-hacker-box";
    port = 3456;

    # JWTSecret + any future secrets come from this file, never the store.
    environmentFiles = [ "/etc/vikunja/env" ];

    settings = {
      service = {
        enableregistration = true; # flip to false after first account
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
  # Auto-provision the JWT secret on first boot so that `vikunja.service`
  # starts cleanly on a fresh install without any manual step.
  # ---------------------------------------------------------------------------
  systemd.services.vikunja-secret-init = {
    description = "Generate Vikunja JWT secret on first boot";
    wantedBy = [ "vikunja.service" ];
    before = [ "vikunja.service" ];
    path = with pkgs; [
      openssl
      coreutils
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # NixOS's vikunja module runs the daemon under a DynamicUser, so
    # `vikunja` is not a static account. `EnvironmentFile=` is loaded by
    # systemd as root BEFORE dropping privileges, so root:root 0400 is
    # both sufficient and the safest permissions.
    script = ''
      set -euo pipefail
      install -d -m 0700 -o root -g root /etc/vikunja
      if [ ! -s /etc/vikunja/env ]; then
        umask 077
        secret=$(openssl rand -hex 32)
        printf 'VIKUNJA_SERVICE_JWTSECRET=%s\n' "$secret" > /etc/vikunja/env
        chmod 0400 /etc/vikunja/env
      fi
    '';
  };
}
