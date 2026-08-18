/*
  media/arr-stack.nix — Automated media download stack with VPN kill-switch.

  Service map
  -----------
  Prowlarr     9696/tcp   Indexer aggregator (feeds Sonarr + Radarr).
  Sonarr       8989/tcp   TV-show automation.
  Radarr       7878/tcp   Movie automation.
  qBittorrent  8080/tcp   Headless torrent client (WebUI), 6881/tcp+udp (P2P).

  VPN isolation (WireGuard)
  -------------------------
  Only qBittorrent traffic is routed through the VPN tunnel (wg0).

  Routing strategy:
    1. ip rule routes packets from UID=qbittorrent through table 100.
    2. Table 100 has a single default route via wg0.
    3. An iptables OUTPUT rule drops any non-wg0 packet from that UID
       as a belt-and-suspenders kill-switch.
    4. qBittorrent is systemd-bound to wg-quick-wg0.service — it stops
       if the tunnel drops.

  *** ACTION REQUIRED — fill in the three WireGuard placeholders below:
        address        Your VPN-assigned IP, e.g. 10.64.0.3/32
        publicKey      Your VPN provider's server public key
        endpoint       VPN server host:port, e.g. nl-01.vpn.example.com:51820

  Private key setup (one-time):
    wg genkey | sudo tee /etc/wireguard/wg0.key
    sudo chmod 600 /etc/wireguard/wg0.key
  Most VPN providers (Mullvad, ProtonVPN, etc.) supply a WireGuard config
  file — copy the PrivateKey line value into /etc/wireguard/wg0.key. ***

  Post-setup wiring (do after first `nixos-rebuild switch`)
  ---------------------------------------------------------
  1. Open Prowlarr at :9696 → Indexers → Add your preferred trackers.
  2. Sonarr :8989 → Settings → Download Clients → Add qBittorrent
       Host: 127.0.0.1  Port: 8080  Category: tv
  3. Radarr :7878 → Settings → Download Clients → Add qBittorrent
       Host: 127.0.0.1  Port: 8080  Category: movies
  4. Sonarr/Radarr → Settings → Indexers → Add Prowlarr
       (use the API key shown in Prowlarr → Settings → General).

  Remote queue management
  -----------------------
  Sonarr and Radarr expose a full REST API. Use the Radarr/Sonarr mobile
  apps or LunaSea to add movies/shows from the Pixel 9a or ThinkPad
  (accessible from anywhere via Tailscale MagicDNS).
*/
{ pkgs, ... }:
{
  # ---------------------------------------------------------------------------
  # WireGuard VPN tunnel
  # ---------------------------------------------------------------------------

  networking.wg-quick.interfaces.wg0 = {
    # Path to the file containing only the raw private key (no [Interface] header).
    privateKeyFile = "/etc/wireguard/wg0.key";

    # *** REPLACE: your VPN-assigned IP address
    address = [ "10.x.x.x/32" ];

    # Routing is managed manually in postUp so only qbittorrent uses the tunnel.
    # Setting table = "off" prevents wg-quick from touching the main routing table.
    table = "off";

    peers = [
      {
        # *** REPLACE: VPN server public key
        publicKey = "REPLACE_WITH_VPN_SERVER_PUBLIC_KEY=";
        # *** REPLACE: VPN server endpoint
        endpoint = "vpn.example.com:51820";
        # Route all traffic through the tunnel (routing rules below restrict
        # which UID actually uses this).
        allowedIPs = [
          "0.0.0.0/0"
          "::/0"
        ];
        persistentKeepalive = 25;
      }
    ];

    postUp = ''
      # Routing table 100: default via wg0.
      ${pkgs.iproute2}/bin/ip route add default dev wg0 table 100

      # Route only the qbittorrent UID through table 100.
      ${pkgs.iproute2}/bin/ip rule add \
        uidrange $(id -u qbittorrent)-$(id -u qbittorrent) \
        table 100 priority 100

      # Kill-switch: drop packets from qbittorrent that leave via any
      # interface other than wg0 (catches leaks if table 100 is bypassed).
      ${pkgs.iptables}/bin/iptables  -A OUTPUT ! -o wg0 \
        -m owner --uid-owner qbittorrent -j DROP
      ${pkgs.iptables}/bin/ip6tables -A OUTPUT ! -o wg0 \
        -m owner --uid-owner qbittorrent -j DROP
    '';

    preDown = ''
      ${pkgs.iproute2}/bin/ip route del default dev wg0 table 100 || true
      ${pkgs.iproute2}/bin/ip rule del \
        uidrange $(id -u qbittorrent)-$(id -u qbittorrent) \
        table 100 priority 100 || true
      ${pkgs.iptables}/bin/iptables  -D OUTPUT ! -o wg0 \
        -m owner --uid-owner qbittorrent -j DROP || true
      ${pkgs.iptables}/bin/ip6tables -D OUTPUT ! -o wg0 \
        -m owner --uid-owner qbittorrent -j DROP || true
    '';
  };

  # ---------------------------------------------------------------------------
  # qBittorrent-nox (headless, VPN-bound)
  # ---------------------------------------------------------------------------

  # All user/group declarations grouped to satisfy statix W20.
  users = {
    users = {
      qbittorrent = {
        isSystemUser = true;
        group = "qbittorrent";
        home = "/var/lib/qbittorrent";
        createHome = true;
        extraGroups = [ "media" ];
      };
      sonarr.extraGroups = [ "media" ];
      radarr.extraGroups = [ "media" ];
    };
    groups.qbittorrent = { };
  };

  systemd.services.qbittorrent = {
    description = "qBittorrent-nox headless torrent client";
    # Hard dependency: qBittorrent stops when the VPN drops.
    after = [
      "network-online.target"
      "wg-quick-wg0.service"
    ];
    requires = [ "wg-quick-wg0.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "exec";
      User = "qbittorrent";
      Group = "qbittorrent";
      ExecStart =
        "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox"
        + " --profile=/var/lib/qbittorrent"
        + " --webui-port=8080";
      Restart = "on-failure";
      RestartSec = "15s";
      # Filesystem: writable only where needed.
      ProtectSystem = "strict";
      ReadWritePaths = [
        "/var/lib/qbittorrent"
        "/srv/nas/downloads"
      ];
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  # WebUI port (P2P runs inside the VPN tunnel).
  networking.firewall.allowedTCPPorts = [ 8080 ];

  # ---------------------------------------------------------------------------
  # Sonarr — TV automation
  # ---------------------------------------------------------------------------

  services = {
    sonarr = {
      enable = true;
      openFirewall = true;
      dataDir = "/var/lib/sonarr";
    };

    # ---------------------------------------------------------------------------
    # Radarr — Movie automation
    # ---------------------------------------------------------------------------

    radarr = {
      enable = true;
      openFirewall = true;
      dataDir = "/var/lib/radarr";
    };

    # ---------------------------------------------------------------------------
    # Prowlarr — Indexer aggregator
    # ---------------------------------------------------------------------------

    prowlarr = {
      enable = true;
      openFirewall = true;
    };
  };
}
