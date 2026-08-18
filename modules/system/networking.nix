/*
  system/networking.nix — Hostname, NetworkManager, locale, time zone, and
  baseline firewall / kernel network tuning.

  NetworkManager
  --------------
  Handles both wired and wireless connections and integrates with the
  nm-applet tray icon used in the Hyprland setup.

  Firewall
  --------
  Enabled explicitly (also the NixOS default). Per-service `allowedTCPPorts`
  entries in individual modules (nextcloud, adguard, forgejo, monitoring)
  extend the accept list. Refused packets are logged so a dropped connection
  during a pentest lab session shows up in `journalctl -u firewall`.

  Kernel sysctl
  -------------
  Tighten a handful of sane network defaults without breaking the workstation
  or the NAS role: TCP BBR congestion control, larger connection backlog,
  ignore ICMP broadcast pings, drop source-routed packets.
*/
_: {
  networking = {
    hostName = "nixos-hacker-box";
    networkmanager.enable = true;
    enableIPv6 = true;

    firewall = {
      enable = true;
      allowPing = true;
      logRefusedPackets = true;
      logRefusedUnicastsOnly = true;
    };
  };

  # ---------------------------------------------------------------------------
  # Kernel network tuning — safe defaults for a desktop + local NAS.
  # ---------------------------------------------------------------------------
  boot.kernel.sysctl = {
    # Congestion control.
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";

    # Connection scaling.
    "net.core.somaxconn" = 4096;
    "net.core.netdev_max_backlog" = 16384;

    # Basic anti-spoof / ICMP hygiene.
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.all.log_martians" = 1;

    # Slightly larger dirty-page window for the media / snapshot workflows.
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 20;
    "vm.swappiness" = 10;
  };

  time.timeZone = "Europe/Rome";
  console.keyMap = "it";

  # Keep the UI in English but format numbers/dates/currency for Italy.
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_TIME = "it_IT.UTF-8";
      LC_NUMERIC = "it_IT.UTF-8";
      LC_MONETARY = "it_IT.UTF-8";
      LC_PAPER = "it_IT.UTF-8";
      LC_MEASUREMENT = "it_IT.UTF-8";
    };
  };
}
