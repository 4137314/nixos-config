/*
  network/caddy.nix — Reverse-proxy with automatic TLS for internal services.

  Architecture
  ------------
     Browser ──► Caddy (:443, TLS) ──► Nextcloud (80)
                                   └─► Grafana    (3000)
                                   └─► Forgejo    (3080)
                                   └─► AdGuard    (3053)
                                   └─► Syncthing  (8384)

  Nextcloud continues to listen on plain HTTP (:80) internally — Caddy
  terminates TLS and forwards. The existing `networking.firewall.allowedTCPPorts`
  entries in each service module stay valid; only the LAN-visible endpoint
  moves behind Caddy.

  Certificates
  ------------
  Two supported modes, chosen at first-run time:

    1) Tailscale certificates (recommended for private-mesh access)
       Requires `services.tailscale.permitCertUid = "caddy"` (set below) plus
       joining the tailnet with MagicDNS. Cert URLs read as:
         https://nixos-hacker-box.<tailnet>.ts.net/

    2) `tls internal` — Caddy's own CA
       Simpler, but every device on the LAN must trust Caddy's root cert
       (available at http://<host>/ca.crt after first run). Useful for
       air-gapped labs.

  Public-internet Let's Encrypt certs are intentionally NOT wired: this box
  does not expose ports 80/443 outside the LAN + tailnet.

  Choose mode
  -----------
  The `tlsPolicy` variable below flips between the two. Default: `internal`
  (works out of the box, no external dependencies). Switch to `tailscale`
  after `tailscale up` has run and MagicDNS is confirmed working.
*/
_:
let
  # Change to "tailscale" once tailnet + MagicDNS are live.
  tlsPolicy = "internal";

  tlsDirective =
    if tlsPolicy == "tailscale" then "tls { get_certificate tailscale }" else "tls internal";

  # Reusable block for every reverse-proxied vhost.
  proxyBlock = upstream: ''
    ${tlsDirective}

    encode zstd gzip

    header {
      Strict-Transport-Security "max-age=31536000; includeSubDomains"
      X-Content-Type-Options    "nosniff"
      X-Frame-Options           "SAMEORIGIN"
      Referrer-Policy           "strict-origin-when-cross-origin"
      -Server
    }

    reverse_proxy ${upstream} {
      header_up X-Real-IP {remote_host}
      header_up X-Forwarded-Proto {scheme}
    }
  '';
in
{
  # Tailscale must be authorised to issue certs on Caddy's behalf.
  services.tailscale.permitCertUid = "caddy";

  services.caddy = {
    enable = true;
    email = "admin@nixos-hacker-box.local";

    # Hostnames use the LAN name; add tailnet FQDN entries after enabling
    # tlsPolicy = "tailscale".
    virtualHosts = {
      # -- Core infrastructure -----------------------------------------------
      "nextcloud.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:8000";
      "grafana.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:3000";
      "git.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:3080";
      "adguard.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:3053";
      "syncthing.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:8384";
      "ntfy.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:2586";

      # -- Personal Hub — native NixOS services -----------------------------
      "rss.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:8081";
      "vault.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:8222";
      "tasks.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:3456";
      "audio.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:8112";
      "music.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:4533";
      "docs.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:28981";
      "photos.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:2283";
      "status.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:3001";

      # -- Personal Hub — container services --------------------------------
      # Vhost entries are commented out ONLY for containers whose backing
      # podman service is currently disabled in hub/containers.nix or
      # ai/containers.nix. Re-enable both the container block AND the
      # matching vhost here when you provision the required config/env.
      # "home.nixos-hacker-box".extraConfig    = proxyBlock "127.0.0.1:8085";  # glance
      "watch.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:5000";
      # "links.nixos-hacker-box".extraConfig   = proxyBlock "127.0.0.1:3005";  # karakeep
      "notes.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:5230";
      "flow.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:5678";
      # "money.nixos-hacker-box".extraConfig   = proxyBlock "127.0.0.1:8083";  # firefly
      # "invest.nixos-hacker-box".extraConfig  = proxyBlock "127.0.0.1:3333";  # ghostfolio
      "tools.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:8880";
      "cyber.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:8886";

      # -- AI stack -----------------------------------------------------------
      "ai.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:8080";
      "ollama.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:11434";
      "qdrant.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:6333";
      "search.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:8889";
      # "perplex.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:3010";  # perplexica
      # "flow-ai.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:3009";  # flowise
      "ha.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:8123";

      # -- IoT + NVR ----------------------------------------------------------
      "z2m.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:8084";
      "esphome.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:6052";
      "nvr.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:5001";

      # -- Hub extras (Trilium, scraping, knowledge, finance) ----------------
      "wiki.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:8082";
      "rss-bridge.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:3062";
      # "crawl.nixos-hacker-box".extraConfig   = proxyBlock "127.0.0.1:3002";  # firecrawl
      # "sb.nixos-hacker-box".extraConfig      = proxyBlock "127.0.0.1:3025";  # silverbullet
      # "kiwix.nixos-hacker-box".extraConfig   = proxyBlock "127.0.0.1:8087";  # kiwix
      "archive.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:8088";
      # "openbb.nixos-hacker-box".extraConfig  = proxyBlock "127.0.0.1:6900";  # openbb
      "budget.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:5006";

      # -- Attic self-hosted binary cache ------------------------------------
      "cache.nixos-hacker-box".extraConfig = proxyBlock "127.0.0.1:8090";
    };
  };

  # Caddy must be able to bind :80 (HTTP redirect) and :443.
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
