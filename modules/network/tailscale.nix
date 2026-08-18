/*
  network/tailscale.nix — Tailscale VPN with Exit Node + MagicDNS.

  What this enables
  -----------------
  • All your devices (Pixel 9a, ThinkPad, this box) form a private mesh.
  • MagicDNS resolves nixos-hacker-box.<tailnet>.ts.net from any device.
  • Exit Node: route Pixel 9a traffic through this box when on public Wi-Fi.
  • Subnet routing: expose 192.168.x.0/24 (your LAN) to remote clients.

  First-time activation (run once after `nixos-rebuild switch`)
  -------------------------------------------------------------
  # Authenticate and advertise as exit node + LAN subnet:
  sudo tailscale up \
    --advertise-exit-node \
    --advertise-routes=192.168.1.0/24 \   ← adjust to your LAN CIDR
    --accept-routes \
    --accept-dns=false                      ← we use AdGuard locally

  # Then approve the exit node in https://login.tailscale.com/admin/machines
  # (click the three dots next to this machine → Edit route settings).

  Pixel 9a setup
  --------------
  Install Tailscale → tap the machine → "Use as exit node".
  All traffic from the phone then tunnels through this box.

  MagicDNS
  ---------
  With --accept-dns=false we intentionally keep AdGuard as the local
  resolver and prevent Tailscale from overriding /etc/resolv.conf.
  Tailscale MagicDNS still works for cross-device hostname resolution
  because it operates at the Tailscale layer, not the system resolver.

  Services accessible from anywhere via MagicDNS
  -----------------------------------------------
  http://nixos-hacker-box.<tailnet>.ts.net       Nextcloud / nginx
  http://nixos-hacker-box.<tailnet>.ts.net:8096  Jellyfin
  http://nixos-hacker-box.<tailnet>.ts.net:8989  Sonarr
  http://nixos-hacker-box.<tailnet>.ts.net:7878  Radarr
  http://nixos-hacker-box.<tailnet>.ts.net:3000  Grafana
*/
_: {
  services.tailscale = {
    enable = true;
    # "server" enables kernel IP forwarding needed for exit-node + subnet routing.
    useRoutingFeatures = "server";
  };

  networking.firewall = {
    # Required for exit-node traffic forwarding (prevents reverse path filter drops).
    checkReversePath = "loose";
    # Trust the Tailscale tunnel interface — no firewall rules between tailscale peers.
    trustedInterfaces = [ "tailscale0" ];
  };
}
