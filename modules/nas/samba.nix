_:

# ─────────────────────────────────────────────────────────────────────────────
# NAS — Condivisione rete via SMB/CIFS (Samba).
#
# Accesso dalla rete locale:
#   Windows : \\nixos-hacker-box\archive
#   macOS   : smb://nixos-hacker-box.local/archive
#   Linux   : smb://nixos-hacker-box.local/archive
#
# Prima configurazione (una tantum):
#   sudo smbpasswd -a main
# ─────────────────────────────────────────────────────────────────────────────
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
        # Performance
        "socket options" = "TCP_NODELAY IPTOS_LOWDELAY";
        "read raw"       = "yes";
        "write raw"      = "yes";
      };

      # Share del disco archive montato su /mnt/archive
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

  # mDNS: rende il NAS raggiungibile come "nixos-hacker-box.local"
  # su macOS e Linux senza configurare DNS manualmente.
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
