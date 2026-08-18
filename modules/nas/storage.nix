/*
  nas/storage.nix — Btrfs NAS storage layout with automated snapshots.

  Disk layout (label: nas)
  ------------------------
  A single Btrfs volume with three named subvolumes. Mount the root
  volume first to create them (one-time, see "First-time setup" below).

    @media      → /srv/nas/media      (films, tv, music)
    @downloads  → /srv/nas/downloads  (torrent watch dir + completed)
    @nextcloud  → /srv/nas/nextcloud  (Nextcloud data directory)

  First-time disk preparation
  ---------------------------
  Run these commands ONCE on a new/empty disk:

    sudo mkfs.btrfs -L nas /dev/sdX          # format (replace sdX)
    sudo mount /dev/sdX /mnt
    sudo btrfs subvolume create /mnt/@media
    sudo btrfs subvolume create /mnt/@downloads
    sudo btrfs subvolume create /mnt/@nextcloud
    sudo umount /mnt

  Then run `nixos-rebuild switch` — the fileSystems entries below will
  mount each subvolume at its final path automatically.

  Shared group "media"
  --------------------
  jellyfin, sonarr, radarr, and qbittorrent all run under this group.
  User "main" is also added (see configuration.nix) for CLI access.

  Snapshots (snapper)
  -------------------
  Hourly timeline snapshots are taken for each subvolume.
  Manually trigger: sudo snapper -c media create --description "manual"
  List:            sudo snapper -c media list
*/
_: {
  # ---------------------------------------------------------------------------
  # Btrfs subvolume mounts
  # ---------------------------------------------------------------------------

  fileSystems = {
    "/srv/nas/media" = {
      device = "/dev/disk/by-label/nas";
      fsType = "btrfs";
      options = [
        "subvol=@media"
        "compress=zstd:3"
        "noatime"
        "nofail"
      ];
    };
    "/srv/nas/downloads" = {
      device = "/dev/disk/by-label/nas";
      fsType = "btrfs";
      options = [
        "subvol=@downloads"
        "compress=zstd:3"
        "noatime"
        "nofail"
      ];
    };
    "/srv/nas/nextcloud" = {
      device = "/dev/disk/by-label/nas";
      fsType = "btrfs";
      options = [
        "subvol=@nextcloud"
        "compress=zstd:3"
        "noatime"
        "nofail"
      ];
    };
  };

  # ---------------------------------------------------------------------------
  # Shared group for all media services
  # ---------------------------------------------------------------------------

  users.groups.media = { };

  # ---------------------------------------------------------------------------
  # Directory skeleton (created at boot, idempotent)
  # ---------------------------------------------------------------------------

  systemd.tmpfiles.rules = [
    # Media library — owned by root:media so any service in the group can write.
    "d /srv/nas/media              0775 root media -"
    "d /srv/nas/media/films        0775 root media -"
    "d /srv/nas/media/tv           0775 root media -"
    "d /srv/nas/media/music        0775 root media -"

    # Downloads — watch/ is where *arr drops .torrent/.magnet files.
    "d /srv/nas/downloads          0775 root media -"
    "d /srv/nas/downloads/torrent  0775 root media -"
    "d /srv/nas/downloads/watch    0775 root media -"

    # Nextcloud data — owned exclusively by the nextcloud service user.
    "d /srv/nas/nextcloud          0700 nextcloud nextcloud -"
  ];

  # ---------------------------------------------------------------------------
  # Automated Btrfs snapshots via snapper
  # ---------------------------------------------------------------------------

  services.snapper.configs = {
    media = {
      SUBVOLUME = "/srv/nas/media";
      ALLOW_USERS = [ "main" ];
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      TIMELINE_MIN_AGE = 1800;
      TIMELINE_LIMIT_HOURLY = 10;
      TIMELINE_LIMIT_DAILY = 7;
      TIMELINE_LIMIT_WEEKLY = 4;
      TIMELINE_LIMIT_MONTHLY = 6;
    };

    downloads = {
      SUBVOLUME = "/srv/nas/downloads";
      ALLOW_USERS = [ "main" ];
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      TIMELINE_MIN_AGE = 1800;
      TIMELINE_LIMIT_HOURLY = 5;
      TIMELINE_LIMIT_DAILY = 3;
      TIMELINE_LIMIT_WEEKLY = 0;
      TIMELINE_LIMIT_MONTHLY = 0;
    };

    nextcloud = {
      SUBVOLUME = "/srv/nas/nextcloud";
      ALLOW_USERS = [ "main" ];
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      TIMELINE_MIN_AGE = 1800;
      TIMELINE_LIMIT_HOURLY = 10;
      TIMELINE_LIMIT_DAILY = 7;
      TIMELINE_LIMIT_WEEKLY = 4;
      TIMELINE_LIMIT_MONTHLY = 6;
    };
  };
}
