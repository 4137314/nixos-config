/*
  system/journald.nix — Persistent systemd journal with sane limits.

  Persistence
  -----------
  Journald default is `Storage=auto` which persists to /var/log/journal if
  the directory exists. We force `persistent` and pre-create the directory
  so logs survive reboots (critical for post-mortem after unclean shutdown).

  Retention
  ---------
  Keep at most 2 GiB of journal on disk, no older than 60 days. On this box
  (~250 GB NVMe) that's a rounding error but stops runaway logs from a
  crash-looping service from eating the root filesystem.

  Compression
  -----------
  Enabled — journald uses zstd by default in recent systemd.

  Rate limiting
  -------------
  Slightly relaxed so verbose apps (dev builds, tcpdump piped to journal)
  don't drop lines silently.
*/
_: {
  services.journald = {
    storage = "persistent";
    extraConfig = ''
      SystemMaxUse=2G
      SystemKeepFree=1G
      SystemMaxFileSize=128M
      SystemMaxFiles=32
      MaxRetentionSec=60day
      MaxFileSec=1week

      Compress=yes
      Seal=yes

      ForwardToSyslog=no
      ForwardToKMsg=no
      ForwardToConsole=no

      RateLimitIntervalSec=30s
      RateLimitBurst=20000
    '';
  };

  systemd.tmpfiles.rules = [
    "d /var/log/journal 2755 root systemd-journal - -"
  ];
}
