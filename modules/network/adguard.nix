/*
  network/adguard.nix — AdGuard Home network-level DNS filter + local DNS.

  What this does
  --------------
  • Blocks ads, trackers, and malware at DNS level for all LAN devices.
  • Resolves local service names (*.nixos-hacker-box) without editing
    /etc/hosts on every client — point each device's DNS to this box's IP.
  • Provides DNS-over-HTTPS upstream for privacy.

  systemd-resolved conflict
  -------------------------
  NixOS enables systemd-resolved by default with a stub listener on :53.
  We disable the stub so AdGuard can bind port 53 instead.
  The machine itself continues to resolve via 127.0.0.1 (AdGuard).

  Router / DHCP setup (recommended)
  ----------------------------------
  Set your router's DHCP DNS server to this machine's LAN IP
  (e.g. 192.168.1.100) so ALL devices on the network use AdGuard
  without any per-device configuration.
  Alternatively, configure DNS manually per device.

  *** ACTION REQUIRED — replace SERVER_LAN_IP below with this machine's
      actual LAN IP address (e.g. "192.168.1.100"). ***

  Admin Web UI
  ------------
  http://nixos-hacker-box:3053  (first run: setup wizard)
  Default credentials are set in the setup wizard.

  Local DNS rewrites
  ------------------
  The `rewrites` list below makes these hostnames resolve to this machine:
    nixos-hacker-box      → SERVER_LAN_IP
    *.nixos-hacker-box    → SERVER_LAN_IP
  Clients can then reach Nextcloud, Jellyfin, Grafana etc. by name.
*/
_: {
  # Disable systemd-resolved's stub listener so AdGuard can bind :53.
  services.resolved = {
    extraConfig = ''
      DNSStubListener=no
    '';
    # Fall back to the machine's own AdGuard instance for local resolution.
    fallbackDns = [ "127.0.0.1" ];
  };

  services.adguardhome = {
    enable = true;
    openFirewall = true;

    # mutableSettings = true: the Nix settings below are written only on
    # first run. After that, blocklists, rewrites, and admin credentials
    # set through the web UI at :3053 are preserved across rebuilds.
    # Set to false only if you want full declarative control (requires
    # adding a bcrypt admin password hash to settings.users below).
    mutableSettings = true;

    settings = {
      # -----------------------------------------------------------------------
      # HTTP admin interface — loopback only. Reach it via Caddy at
      # https://adguard.nixos-hacker-box. During first-run before Caddy
      # is proxying, use an SSH tunnel: `ssh -L 3053:127.0.0.1:3053 box`.
      #
      # mutableSettings = true means this only applies to a fresh install;
      # on existing installs the value in
      # /var/lib/AdGuardHome/AdGuardHome.yaml wins. When migrating from a
      # 0.0.0.0 bind, stop the service, edit that yaml, then start again.
      # -----------------------------------------------------------------------
      http = {
        address = "127.0.0.1:3053";
      };

      # -----------------------------------------------------------------------
      # DNS server
      # -----------------------------------------------------------------------
      dns = {
        # Explicit bind list — DO NOT use "0.0.0.0". Podman's aardvark-dns
        # (netavark backend) needs :53 on every container-bridge IP
        # (10.88.0.1, 10.89.x.1, …) for container name resolution.
        # Binding AdGuard to "0.0.0.0" steals those IPs and every podman
        # container fails to start.
        # Add more LAN IPs here if the host has multiple interfaces.
        bind_hosts = [
          "127.0.0.1"
          "192.168.1.143"
        ];
        port = 53;
        # DNS-over-HTTPS upstream resolvers for privacy.
        upstream_dns = [
          "https://dns.cloudflare.com/dns-query"
          "https://dns.google/dns-query"
        ];
        # Plain DNS used only for bootstrapping DoH (needed before DoH works).
        bootstrap_dns = [
          "1.1.1.1"
          "8.8.8.8"
        ];
        # Cache 1 hour.
        cache_size = 4194304;
        cache_ttl_min = 300;
      };

      # -----------------------------------------------------------------------
      # Filtering block-lists
      # -----------------------------------------------------------------------
      filters = [
        {
          enabled = true;
          url = "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt";
          name = "AdGuard DNS filter";
          id = 1;
        }
        {
          enabled = true;
          url = "https://adaway.org/hosts.txt";
          name = "AdAway Default Blocklist";
          id = 2;
        }
        {
          enabled = true;
          url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts";
          name = "StevenBlack Unified Hosts";
          id = 3;
        }
      ];

      # -----------------------------------------------------------------------
      # Local DNS rewrites — resolves service names to this machine's LAN IP.
      # *** REPLACE "SERVER_LAN_IP" with the actual IP (e.g. 192.168.1.100) ***
      # -----------------------------------------------------------------------
      filtering.rewrites = [
        {
          domain = "nixos-hacker-box";
          answer = "192.168.1.143";
        }
        {
          domain = "*.nixos-hacker-box";
          answer = "192.168.1.143";
        }
      ];
    };
  };

  # No LAN-facing firewall opening for the admin UI — Caddy proxies it
  # at https://adguard.nixos-hacker-box. DNS on :53 is opened by
  # `services.adguardhome.openFirewall = true;` above.
}
