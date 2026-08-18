/*
  backup/postgres.nix — Logical SQL dumps of every PostgreSQL database.

  Why
  ---
  restic (backup/restic.nix) copies the raw PGDATA directory. That works
  for same-version restore but breaks cross-major (16 → 17). A daily
  logical dump gives you a portable `.sql.zst` that restores anywhere.

  Databases covered
  -----------------
  Only databases that actually exist on this host at eval time. Adding
  a new PG-backed service is a two-step change: enable the service
  (which creates the DB via `services.postgresql.ensureDatabases`) AND
  append its name to the list below.

  Deliberately NOT dumped:
    - vikunja  → SQLite (see hub/vikunja.nix), covered by restic file backup.
    - immich   → hub/default.nix module is currently disabled; add back once
                 immich.nix is imported.

  Location & retention
  --------------------
  /var/backup/postgresql/<db>-<date>.sql.gz
  Kept 14 days locally by the NixOS module. The whole dir is included
  by restic via /var/backup path in modules/backup/restic.nix.

  Schedule
  --------
  Daily at 02:30 — well before restic's 03:00 offsite run picks it up.
*/
_: {
  services.postgresqlBackup = {
    enable = true;
    startAt = "*-*-* 02:30:00";
    location = "/var/backup/postgresql";
    compression = "gzip";
    compressionLevel = 6;

    # Explicit whitelist — a stray DB accidentally created by an app
    # installer will NOT be dumped.
    databases = [
      "nextcloud"
    ];
  };

  # Include the dumps in the restic backup path list.
  systemd.tmpfiles.rules = [
    "d /var/backup            0750 postgres postgres -"
    "d /var/backup/postgresql 0750 postgres postgres -"
  ];
}
