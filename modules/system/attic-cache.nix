/*
  system/attic-cache.nix — Self-hosted Nix binary cache (Attic).

  Purpose
  -------
  This box builds a lot: containers, ollama models, GPU drivers, and
  every module change. Attic runs a local S3-like store + HTTP API,
  signed with an ed25519 key. Local `nix-daemon` uses it as the first
  substituter — cache-misses fall through to cache.nixos.org.

  Access
  ------
  Web + API on http://127.0.0.1:8090, exposed via Caddy at
  https://cache.nixos-hacker-box.

  First-run
  ---------
    1. sudo systemctl start atticd
    2. sudo -u atticd atticd-atticadm make-token \
         --sub "operator" --validity "1y" \
         --pull "nixos-hacker-box" --push "nixos-hacker-box"
       # save the token in Vaultwarden
    3. On any client (this box counts):
         nix run nixpkgs#attic-client -- login \
           local https://cache.nixos-hacker-box <token>
         nix run nixpkgs#attic-client -- use local:nixos-hacker-box
    4. Push local builds explicitly (or wire post-build-hook):
         nix run nixpkgs#attic-client -- push local:nixos-hacker-box \
           $(nix-store -qR /run/current-system)

  Storage
  -------
  /var/lib/atticd holds compressed NAR archives. Grows unbounded — set
  `--gc-max-age` if space is tight.
*/
_: {
  services.atticd = {
    enable = true;

    # File must contain: ATTIC_SERVER_TOKEN_RS256_SECRET="<base64-rsa-private>"
    # Generate once:
    #   sudo mkdir -p /var/lib/atticd
    #   ( echo -n 'ATTIC_SERVER_TOKEN_RS256_SECRET="'; \
    #     openssl genrsa -traditional 4096 | base64 -w0; \
    #     echo '"' ) | sudo tee /var/lib/atticd/env
    #   sudo chmod 600 /var/lib/atticd/env
    #   sudo chown atticd:atticd /var/lib/atticd/env
    environmentFile = "/var/lib/atticd/env";

    settings = {
      listen = "127.0.0.1:8090";
      allowed-hosts = [
        "cache.nixos-hacker-box"
        "127.0.0.1"
        "localhost"
      ];
      api-endpoint = "https://cache.nixos-hacker-box/";

      storage = {
        type = "local";
        path = "/var/lib/atticd/storage";
      };

      chunking = {
        nar-size-threshold = 65536;
        min-size = 16384;
        avg-size = 65536;
        max-size = 262144;
      };

      compression = {
        type = "zstd";
        level = 6;
      };

      garbage-collection = {
        interval = "12 hours";
        default-retention-period = "6 months";
      };
    };
  };

  # Use the local cache as the first substituter — cache.nixos.org still
  # covers what atticd doesn't have.
  nix.settings = {
    substituters = [
      "https://cache.nixos-hacker-box"
    ];
    # The pubkey below is placeholder — replace after `atticd` boots once
    # and generates its signing key at /var/lib/atticd/hs256_secret_key.
    # Get the matching public key with:
    #   sudo cat /var/lib/atticd/hs256_secret_key   # (base64)
    # For an ed25519 signing key attic prints the public key on first run.
    trusted-public-keys = [
      # "nixos-hacker-box:REPLACE_AFTER_FIRST_BOOT="
    ];
  };
}
