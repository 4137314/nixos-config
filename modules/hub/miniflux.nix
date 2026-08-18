/*
  hub/miniflux.nix — Self-hosted RSS / Atom aggregator.

  Why Miniflux
  ------------
  Single Go binary, PostgreSQL backend, clean JSON API for automations
  (n8n can subscribe to feeds and forward interesting items to ntfy).
  No JavaScript client — the web UI is server-rendered, works from a
  slow mobile network.

  Storage
  -------
  Uses the shared local PostgreSQL that ships with the NixOS module.
  State (feed cache, favicons) lives in Postgres — nightly restic run
  covers it via /var/lib/postgresql.

  Access
  ------
  http://127.0.0.1:8081 direct, https://rss.nixos-hacker-box behind Caddy
  (see network/caddy.nix). Default admin credentials are set on first
  activation from an env file — see FIRST-RUN.

  First-run
  ---------
    sudo install -d -o miniflux -g miniflux -m 750 /var/lib/miniflux
    sudo tee /var/lib/miniflux/admin-pass >/dev/null <<'EOF'
    ADMIN_USERNAME=admin
    ADMIN_PASSWORD=<strong-password-here>
    EOF
    sudo chmod 640 /var/lib/miniflux/admin-pass
    sudo chown miniflux:miniflux /var/lib/miniflux/admin-pass
    sudo systemctl restart miniflux
    → open http://<host>:8081 and log in as `admin`
*/
_: {
  services.miniflux = {
    enable = true;
    config = {
      LISTEN_ADDR = "127.0.0.1:8081";
      BASE_URL = "https://rss.nixos-hacker-box/";
      METRICS_COLLECTOR = "1";
      METRICS_ALLOWED_NETWORKS = "127.0.0.1/32";
      # Cleanup archived entries after 90 days.
      CLEANUP_ARCHIVE_READ_DAYS = "60";
      CLEANUP_ARCHIVE_UNREAD_DAYS = "180";
      # Fetch schedule
      POLLING_FREQUENCY = "60"; # minutes between rounds
      POLLING_PARSING_ERROR_LIMIT = "3";
      BATCH_SIZE = "100";
    };

    # NixOS default: read admin password from ADMIN_PASSWORD env, which
    # we source from the credentials directory below.
    adminCredentialsFile = "/var/lib/miniflux/admin-pass";
  };
}
