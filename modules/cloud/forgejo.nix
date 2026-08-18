/*
  cloud/forgejo.nix — Self-hosted Forgejo git server.

  Overview
  --------
  Forgejo is a lightweight community fork of Gitea. It provides a full
  GitHub-like experience (repositories, issues, pull requests, CI/actions,
  Git LFS) in a single Go binary with an SQLite backend.

    Web UI      http://nixos-hacker-box:3080
    Git via SSH ssh://git@nixos-hacker-box:2222/<user>/<repo>.git
    Git via HTTP http://nixos-hacker-box:3080/<user>/<repo>.git
    State dir   /var/lib/forgejo   (NixOS default)
    Database    SQLite             (/var/lib/forgejo/data/forgejo.db)

  SSH transport
  -------------
  Forgejo's built-in Go SSH server listens on port 2222, keeping the
  system OpenSSH daemon on port 22 untouched. Add your SSH public key
  from Settings → SSH/GPG Keys in the web UI after first login.

  First run
  ---------
  1. `nixos-rebuild switch`
  2. Open http://nixos-hacker-box:3080. The setup wizard fields are
     pre-populated from this config — just create the admin account.
  3. Add your SSH public key: avatar → Settings → SSH/GPG Keys.
  4. Test:
       git clone ssh://git@nixos-hacker-box:2222/main/repo.git

  Public registration is disabled: create additional users manually from
  Site Administration → User Accounts.

  Migrating state to the Btrfs NAS (optional, for snapshots)
  ----------------------------------------------------------
  1. Create the @forgejo subvolume + add a fileSystems entry in
     modules/nas/storage.nix (mirror the @nextcloud entry).
  2. sudo systemctl stop forgejo
  3. sudo cp -a /var/lib/forgejo/. /srv/nas/forgejo/
  4. sudo chown -R forgejo:forgejo /srv/nas/forgejo
  5. Set  stateDir = "/srv/nas/forgejo";  below.
  6. sudo systemctl start forgejo
*/
_: {
  services.forgejo = {
    enable = true;
    lfs.enable = true;

    database.type = "sqlite3";

    settings = {
      server = {
        DOMAIN = "git.nixos-hacker-box";
        ROOT_URL = "https://git.nixos-hacker-box/";
        # Loopback-only: LAN access goes through Caddy (https on :443).
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3080;

        # Built-in Go SSH server, listening on loopback only. To clone
        # from another host, use the Tailscale IP or the caddy `git`
        # vhost; the LAN interface never sees this port.
        START_SSH_SERVER = true;
        SSH_DOMAIN = "git.nixos-hacker-box";
        SSH_PORT = 2222; # advertised in clone URLs
        SSH_LISTEN_HOST = "127.0.0.1";
        SSH_LISTEN_PORT = 2222; # actual bind port
      };

      service = {
        DISABLE_REGISTRATION = true;
        REQUIRE_SIGNIN_VIEW = true;
      };

      # Caddy terminates TLS in front of us — treat the session as secure.
      session.COOKIE_SECURE = true;
    };
  };

  # No LAN-facing firewall opening: reach Forgejo via
  # https://git.nixos-hacker-box (Caddy) or the tailnet loopback tunnel.
}
