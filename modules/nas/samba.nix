/*
  nas/samba.nix — Samba SMB/CIFS file server for the local network.

  Share layout
  ------------
  archive   Maps to /mnt/archive (secondary disk, ext4).
            Read/write for user "main", no guest access.
  media     Maps to /srv/nas/media (Btrfs subvolume, see nas/storage.nix).
            Read/write for the "media" group (jellyfin, sonarr, radarr, main).

  Network discovery
  -----------------
  Avahi (mDNS/DNS-SD) publishes the host as nixos-hacker-box.local on the
  local network. macOS Finder and Linux file managers discover it
  automatically; Windows clients can use the IP address directly.

  Access paths
  ------------
  Windows   \\nixos-hacker-box\archive    \\nixos-hacker-box\media
  macOS     smb://nixos-hacker-box.local/archive
  Linux     smb://nixos-hacker-box.local/media

  First-time setup (run once after `nixos-rebuild switch`)
  ---------------------------------------------------------
    sudo smbpasswd -a main
*/
_: {
  services.samba = {
    enable = true;
    openFirewall = true;

    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = "HackerBox NAS";
        security = "user";
        "map to guest" = "never";
        "log level" = "1";
        # Performance tuning
        "socket options" = "TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072";
        "read raw" = "yes";
        "write raw" = "yes";
        "use sendfile" = "yes";
        "min receivefile size" = "16384";
      };

      media = {
        path = "/srv/nas/media";
        comment = "Media Library";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "@media";
        "create mask" = "0664";
        "directory mask" = "0775";
        "force group" = "media";
      };
    };
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };
}
