/*
  media/jellyfin.nix — Jellyfin open-source media server.

  Jellyfin scans /srv/nas/media and transcodes on demand.
  The service user is automatically created by the NixOS module; we add it
  to the "media" group (defined in nas/storage.nix) so it can read shared
  library files, and to "video"/"render" for hardware-accelerated transcoding.

  Hardware acceleration (VAAPI)
  ------------------------------
  Intel/AMD iGPUs expose /dev/dri/renderD128. The jellyfin user needs the
  "render" group to access it.
  Enable in Jellyfin: Dashboard → Playback → Transcoding → VAAPI.

  Web UI
  ------
  First run:  http://nixos-hacker-box:8096  (setup wizard)
  Dashboard:  http://nixos-hacker-box:8096/web

  Add libraries in the wizard, pointing to:
    Films  →  /srv/nas/media/films
    TV     →  /srv/nas/media/tv
    Music  →  /srv/nas/media/music

  Firewall ports (opened automatically via openFirewall)
  -------------------------------------------------------
  8096/tcp  HTTP
  8920/tcp  HTTPS (optional)
  7359/udp  LAN client auto-discovery
*/
_: {
  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  # Grant read access to /srv/nas/media and hardware transcoding devices.
  users.users.jellyfin.extraGroups = [
    "media"
    "video"
    "render"
  ];

  # ---------------------------------------------------------------------------
  # Transcode cache on tmpfs (RAM) — avoids NVMe wear during long transcodes.
  # 4 GiB is plenty for two concurrent 1080p streams. Bump to 8G for 4K.
  # Owned by jellyfin so the service can write; readable by media group.
  # ---------------------------------------------------------------------------
  fileSystems."/var/cache/jellyfin/transcodes" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "size=4G"
      "mode=0770"
      "uid=jellyfin"
      "gid=jellyfin"
      "noatime"
      "nosuid"
      "nodev"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /var/cache/jellyfin              0755 jellyfin jellyfin -"
    "d /var/cache/jellyfin/transcodes   0770 jellyfin jellyfin -"
  ];
}
