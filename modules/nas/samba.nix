/*
  nas/samba.nix — Samba SMB/CIFS file server for the local network.

  Share layout
  ------------
  archive   Maps to /mnt/archive (secondary disk, ext4).
            Read/write for user "main", no guest access.

  Network discovery
  -----------------
  Avahi (mDNS/DNS-SD) publishes the host as nixos-hacker-box.local on the
  local network. macOS Finder and Linux file managers discover it
  automatically; Windows clients can use the IP address directly.

  Access paths
  ------------
  Windows   \\nixos-hacker-box\archive
  macOS     smb://nixos-hacker-box.local/archive
  Linux     smb://nixos-hacker-box.local/archive

  First-time setup (run once after `nixos-rebuild switch`)
  ---------------------------------------------------------
    sudo smbpasswd -a main
*/
_:
{
  services.samba = {
    enable       = true;
    openFirewall = true;

    settings = {
      global = {
        workgroup       = "WORKGROUP";
        "server string" = "HackerBox NAS";
        security        = "user";
        "map to guest"  = "never";
        "log level"     = "1";
        # Performance tuning
        "socket options" = "TCP_NODELAY IPTOS_LOWDELAY";
        "read raw"       = "yes";
        "write raw"      = "yes";
      };

      archive = {
        path             = "/mnt/archive";
        comment          = "Archive Disk";
        browseable       = "yes";
        "read only"      = "no";
        "guest ok"       = "no";
        "valid users"    = "main";
        "create mask"    = "0644";
        "directory mask" = "0755";
        "force user"     = "main";
      };
    };
  };

  services.avahi = {
    enable   = true;
    nssmdns4 = true;
    publish = {
      enable      = true;
      addresses   = true;
      workstation = true;
    };
  };
}
