/*
  system/nix.nix — Nix daemon settings, garbage collection, and store
  optimisation.

  experimental-features
    Enables the new `nix` CLI (nix-command) and Flakes, both of which this
    configuration relies on for every operation.

  auto-optimise-store
    Deduplicates identical files across store paths using hard links.
    Runs opportunistically at build time — no extra service needed.

  Garbage collection
    Weekly GC keeping the last 30 days of generations. Older generations
    are still reachable via nix-collect-garbage --delete-older-than manually.

  Binary caches
    nix-community provides prebuilt Neovim-nightly, Emacs-overlay, and a
    range of dev tools that would otherwise rebuild from source locally.

  system.stateVersion
    Records the NixOS release that first activated this system.
    NEVER change after the first switch — controls defaults for stateful
    subsystems (databases, etc.). Upgrade by bumping the channel, not this.
*/
_: {
  nix = {
    # ----------------------------------------------------------------------
    # Nix daemon runs at idle CPU/IO priority. Interactive workloads stay
    # snappy even during a `chromium` rebuild or a `make switch` burst.
    # ----------------------------------------------------------------------
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedClass = "idle";
    daemonIOSchedPriority = 7;

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      # Parallelism — build many derivations at once.
      max-jobs = "auto";
      cores = 0;

      # Store hygiene.
      auto-optimise-store = true;
      keep-outputs = true;
      keep-derivations = true;
      warn-dirty = false;
      trusted-users = [
        "root"
        "@wheel"
      ];

      # ------------------------------------------------------------------
      # Auto-GC when the store gets tight. Nix triggers a GC that frees
      # (max-free - min-free) bytes whenever the FS has less than min-free
      # bytes available. Avoids "No space left on device" mid-build.
      # ------------------------------------------------------------------
      min-free = 5368709120; # 5 GiB
      max-free = 21474836480; # 20 GiB

      # ------------------------------------------------------------------
      # Fetch tuning — bigger download buffer for parallel substituter
      # pulls, faster failover on unreachable caches, cached negative
      # lookups so an unavailable narinfo doesn't get re-probed every eval.
      # ------------------------------------------------------------------
      download-buffer-size = 524288000; # 500 MiB
      connect-timeout = 5;
      builders-use-substitutes = true;
      narinfo-cache-negative-ttl = 3600;
      tarball-ttl = 604800; # 7 days for flake tarballs

      # Additional community binary cache.
      substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };

    # Weekly automated garbage collection.
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
      persistent = true;
    };

    # Continuous store optimisation via a systemd timer.
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.11";
}
