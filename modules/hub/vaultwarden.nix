/*
  hub/vaultwarden.nix — Self-hosted Bitwarden-compatible password manager.

  Why Vaultwarden
  ---------------
  Rust implementation of the Bitwarden server. Runs on this box in tens of
  MB of RAM, uses the official Bitwarden client apps on every platform,
  and exposes the same API — accounts and vaults migrate freely to/from
  Bitwarden Cloud.

  Storage
  -------
  SQLite by default at /var/lib/vaultwarden. Covered by restic + snapper
  because /var/lib is on the system dataset. Attachments (large secrets)
  also under the same tree.

  Access
  ------
  http://127.0.0.1:8222 direct, https://vault.nixos-hacker-box behind Caddy.
  Signups are disabled — create the first account, then turn them off in
  the admin panel with the token below.

  First-run
  ---------
  The `vaultwarden-secret-init` oneshot below generates
  `/var/lib/vaultwarden/admin.env` with a fresh `ADMIN_TOKEN` on first
  boot so the service starts cleanly. To retrieve the token:
     sudo grep ADMIN_TOKEN /var/lib/vaultwarden/admin.env

  Then:
    1. https://vault.nixos-hacker-box  → create your account.
    2. Open the admin panel at /admin, log in with the token above.
    3. Set SIGNUPS_ALLOWED = false (or restrict via SIGNUPS_DOMAINS_WHITELIST).

  To rotate the token:  sudo rm /var/lib/vaultwarden/admin.env && sudo systemctl restart vaultwarden
*/
{ pkgs, ... }:
{
  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";

    environmentFile = "/var/lib/vaultwarden/admin.env";

    config = {
      DOMAIN = "https://vault.nixos-hacker-box";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;

      SIGNUPS_ALLOWED = false;
      SIGNUPS_VERIFY = true;
      INVITATIONS_ALLOWED = true;

      WEBSOCKET_ENABLED = true;
      WEBSOCKET_ADDRESS = "127.0.0.1";
      WEBSOCKET_PORT = 3012;

      # Log to journald (default). No rotate config needed.
      LOG_LEVEL = "info";

      # Push notifications require a Bitwarden install-id; keep off self-host
      # unless you register one at https://bitwarden.com/host/.
      PUSH_ENABLED = false;
    };
  };

  # ---------------------------------------------------------------------------
  # Auto-provision the admin token on first boot so `vaultwarden.service`
  # starts cleanly. `EnvironmentFile=` is loaded by systemd as root before
  # dropping privileges, so root:root 0400 is safe.
  # ---------------------------------------------------------------------------
  systemd.services.vaultwarden-secret-init = {
    description = "Generate Vaultwarden admin token on first boot";
    wantedBy = [ "vaultwarden.service" ];
    before = [ "vaultwarden.service" ];
    path = with pkgs; [
      openssl
      coreutils
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      install -d -m 0750 -o root -g root /var/lib/vaultwarden
      if [ ! -s /var/lib/vaultwarden/admin.env ]; then
        umask 077
        token=$(openssl rand -base64 48)
        printf 'ADMIN_TOKEN=%s\n' "$token" > /var/lib/vaultwarden/admin.env
        chmod 0400 /var/lib/vaultwarden/admin.env
      fi
    '';
  };
}
