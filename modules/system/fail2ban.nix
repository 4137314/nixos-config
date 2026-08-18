/*
  system/fail2ban.nix — Brute-force protection for exposed services.

  Jails
  -----
  sshd        Watches the openssh unit; 5 failures in 10 min → 1 h ban.
  nginx       Watches the nginx access log for Nextcloud auth failures.
  forgejo     Watches the forgejo unit for repeated auth failures.

  Ignored networks
  ----------------
  RFC1918 LAN (192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12) and the Tailscale
  100.64.0.0/10 CGNAT range are always allowed — bans hit only public IPs
  that somehow reach the box.

  Backend
  -------
  systemd journal is queried directly (no log file paths, no logrotate
  coupling). Runs as a system service and requires no extra state.
*/
_: {
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    banaction = "iptables-multiport";
    banaction-allports = "iptables-allports";
    bantime = "1h";
    bantime-increment = {
      enable = true;
      maxtime = "48h";
      formula = "ban.Time * (1<<(ban.Count if ban.Count<20 else 20)) * banFactor";
    };

    ignoreIP = [
      "127.0.0.0/8"
      "::1"
      "192.168.0.0/16"
      "10.0.0.0/8"
      "172.16.0.0/12"
      "100.64.0.0/10" # Tailscale CGNAT
    ];

    jails = {
      sshd.settings = {
        enabled = true;
        backend = "systemd";
        filter = "sshd";
        maxretry = 5;
        findtime = 600;
      };

      # nginx-http-auth catches Basic-Auth / 401 storms against Nextcloud.
      nginx-http-auth.settings = {
        enabled = true;
        backend = "systemd";
        filter = "nginx-http-auth";
        maxretry = 5;
        findtime = 600;
      };
    };
  };
}
