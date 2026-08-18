/*
  backup/restic.nix — Encrypted offsite backup with restic.

  Sources
  -------
  /home/main               User data (dotfiles + local repos).
  /etc/nixos               The flake itself (in case the box dies).
  /srv/nas/nextcloud       Nextcloud vault (photos, notes, calendar, files).
  /var/lib/forgejo         Git repositories + issue DB.
  /var/lib/grafana         Grafana dashboards + preferences.
  /var/lib/hass            Home Assistant automations + history.
  /var/lib/open-webui      OWU user accounts, chat history, RAG index.
  /var/lib/vikunja         Task DB (SQLite) + attachments.
  /var/lib/hub             All hub container state (Vaultwarden, n8n,
                           Karakeep bookmarks, Memos notes, Firefly, …).
  /var/lib/ai/piper        Custom TTS voice bundles.
  /var/lib/ai/flowise      LangChain workflow definitions.
  /var/lib/ai/perplexica   Perplexica config + uploads.
  /var/backup/postgresql   Nightly logical dumps (see backup/postgres.nix).

  Excluded
  --------
  Rebuildable state — model weights, vector indexes, caches, media
  library. See `exclude` and `extraBackupArgs` below.

    /var/lib/ollama                model weights (~40 GB, `ollama pull`)
    /var/lib/ai/qdrant             vector store (rebuildable from RAG src)
    /var/lib/victoriametrics       long-term metrics (rebuildable trend data)
    /var/lib/loki                  log shipper (short retention anyway)
    /srv/nas/media                 media library (rebuildable/downloadable)

  Destination
  -----------
  Defaults to Backblaze B2 (cheap, fast, dedicated cold storage). Any restic
  backend URL works — S3, Azure, SFTP, rclone remotes. Change `repository`
  and the corresponding environment variables.

  Secrets (via sops-nix, once secrets/secrets.yaml is populated)
  --------------------------------------------------------------
    restic-repo-password    Symmetric encryption key for the repository.
    restic-b2-account-id    Backblaze B2 keyID.
    restic-b2-account-key   Backblaze B2 applicationKey.

  Until sops is bootstrapped, the service references legacy file paths under
  /etc/ — create them with `install -m 400 -o root -g root <file>`.

  Schedule and retention
  ----------------------
  Daily at 03:00. Retention: 7 daily, 4 weekly, 6 monthly, 2 yearly.
  Automatic `restic forget --prune` runs weekly.

  Manual operations
  -----------------
    sudo restic-<name>-repo snapshots         List snapshots.
    sudo restic-<name>-repo restore latest --target /tmp/restore
    sudo systemctl start restic-backups-<name>.service
*/
_: {
  services.restic.backups.offsite = {
    initialize = true;

    # ------------------------------------------------------------------------
    # Destination — Backblaze B2 by default; edit the URL for other backends.
    # ------------------------------------------------------------------------
    repository = "b2:CHANGE-ME-BUCKET-NAME:/nixos-hacker-box";

    # Sops paths (once secrets are populated):
    #   passwordFile     = config.sops.secrets.restic-repo-password.path;
    #   environmentFile  = config.sops.templates."restic-env".path;
    passwordFile = "/etc/restic/repo-password";
    environmentFile = "/etc/restic/env"; # must contain B2_ACCOUNT_ID + B2_ACCOUNT_KEY

    paths = [
      # User data + flake source.
      "/home/main"
      "/etc/nixos"

      # Cloud + git.
      "/srv/nas/nextcloud"
      "/var/lib/forgejo"

      # Observability (dashboards only — metrics themselves are rebuildable).
      "/var/lib/grafana"

      # Domotics + AI UI + tasks.
      "/var/lib/hass"
      "/var/lib/open-webui"
      "/var/lib/vikunja"

      # Personal hub (Vaultwarden, n8n, Karakeep, Memos, Firefly, …).
      "/var/lib/hub"

      # AI stack — small state only; models and vectors are rebuildable.
      "/var/lib/ai/piper"
      "/var/lib/ai/flowise"
      "/var/lib/ai/perplexica"

      # Nightly SQL dumps — cross-version-safe copy of PostgreSQL data.
      "/var/backup/postgresql"
    ];

    exclude = [
      # Home caches / trash / build outputs.
      "/home/main/.cache"
      "/home/main/.local/share/Trash"
      "/home/main/.mozilla/firefox/*/Cache*"
      "/home/main/.config/Code/CachedData"
      "/home/main/.npm"
      "/home/main/.cargo/registry"
      "/home/main/go/pkg"
      "/home/main/Downloads"
      "**/node_modules"
      "**/target"
      "**/.direnv"
      "**/result"

      # Rebuildable service state.
      "/var/lib/ollama" # ~40 GB of model weights, `ollama pull`
      "/var/lib/ai/qdrant" # vector store — re-embed source docs
      "/var/lib/ai/qdrant-snapshots"
      "/var/lib/ai/whisper" # STT model cache (module currently off)
      "/var/lib/ai/searxng" # metasearch config only
    ];

    timerConfig = {
      OnCalendar = "03:00";
      Persistent = true; # run at boot if the box was off at 03:00
      RandomizedDelaySec = "30m";
    };

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
      "--keep-yearly 2"
    ];

    extraBackupArgs = [
      "--one-file-system"
      "--exclude-caches"
      "--compression=auto"
    ];
  };

  # Placeholder ownership rules — remove once sops-nix is providing the files.
  systemd.tmpfiles.rules = [
    "d /etc/restic 0700 root root -"
  ];
}
