/*
  backup/btrbk.nix — Btrfs snapshot replication to a secondary disk.

  Purpose
  -------
  snapper (nas/storage.nix) keeps snapshots on the SAME disk as the source.
  If the disk dies, snapshots die with it. btrbk periodically send/receives
  those snapshots to a second Btrfs volume — locally to a spare disk, or
  via SSH to a remote NAS.

  Target
  ------
  A second Btrfs volume labelled `backup`, mounted at /mnt/backup. Create
  it once with:

    sudo mkfs.btrfs -L backup /dev/sdY
    sudo mkdir -p /mnt/backup
    sudo mount /dev/sdY /mnt/backup
    sudo btrfs subvolume create /mnt/backup/@snapshots

  Then add the persistent mount to modules/nas/storage.nix (mirror the
  existing subvolume entries with fsType = "btrfs"; noatime; nofail).

  Schedule
  --------
  Hourly send/receive. Retention on the backup disk: 24 hourly, 30 daily,
  12 monthly. Adjust `snapshot_preserve` / `target_preserve` per volume.

  Manual operations
  -----------------
    sudo btrbk run                 One-shot send.
    sudo btrbk list snapshots      Show what is on the backup disk.
    sudo btrbk resume              Resume interrupted transfers.
*/
_: {
  services.btrbk = {
    instances.local = {
      onCalendar = "hourly";
      settings = {
        # Where the snapshots live on the source disk (snapper already
        # creates them under .snapshots/ per subvolume).
        snapshot_preserve_min = "2h";
        snapshot_preserve = "48h 14d 8w 12m";

        # Retention on the backup destination.
        target_preserve_min = "no";
        target_preserve = "48h 30d 12m";

        stream_compress = "zstd";
        transaction_log = "/var/log/btrbk.log";

        volume."/srv/nas" = {
          subvolume = {
            media = { };
            downloads = { };
            nextcloud = { };
          };
          target = "/mnt/backup/@snapshots";
        };
      };
    };
  };
}
