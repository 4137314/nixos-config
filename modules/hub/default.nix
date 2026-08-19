/*
  hub/default.nix — Personal Hub aggregator.

  Turns nixos-hacker-box into a fully self-hosted "digital life" server:

    News            Miniflux                RSS/Atom aggregator + API
    Read-later      Karakeep                bookmarks + articles + notes
    Photos          Immich                  Google Photos-class, ML tagging
    Documents       Paperless-ngx           OCR + auto-tagging + search
    Audio           Audiobookshelf          audiobooks + podcasts
                    Navidrome               music (Subsonic API)
    Passwords       Vaultwarden             Bitwarden-compatible
    Notes           Memos                   twitter-like micro-notes
    Tasks           Vikunja                 Todoist-like + Kanban
    Automation      n8n                     visual workflow engine
    Web monitor     changedetection         page diff watcher
    Finance         Firefly III             budgeting + accounts
                    Ghostfolio              investments / portfolio
    Dashboard       Glance                  aggregator with widgets
    Utilities       IT-Tools + CyberChef    dev + data manipulation
    Uptime          Uptime-Kuma             friendly external monitor

  Native modules — enabled directly, state under /var/lib/<service>
  or the Btrfs NAS (immich, paperless).

  Container modules — declared in `containers.nix` under `virtualisation.
  oci-containers.containers` (podman backend, host loopback bind,
  reverse-proxied via Caddy).

  Every hub endpoint gets a Caddy vhost — see modules/network/caddy.nix
  section "Hub vhosts".

  Enabling / disabling
  --------------------
  Comment individual imports here to opt out of a service. All state and
  data lives on disk — a disabled service simply stops answering; its
  files remain until you `rm -rf /var/lib/<service>`.
*/
_: {
  imports = [
    # Native NixOS modules
    ./miniflux.nix
    ./vaultwarden.nix
    ./vikunja.nix
    ./audiobookshelf.nix
    ./navidrome.nix
    ./uptime-kuma.nix
    ./trilium.nix
    # ./paperless.nix     # needs /srv/nas/paperless/{consume,media,data} + admin-pass
    # ./immich.nix        # needs @immich Btrfs subvolume + more storage planning

    # OCI containers (podman) — one file, many services.
    ./containers.nix
    ./archivebox-init.nix # auto-provision ADMIN_PASSWORD

    # Cross-cutting: cap the restart burst of EVERY podman-* unit so a
    # broken container never spins forever and stalls multi-user.target.
    ./podman-hardening.nix
  ];
}
