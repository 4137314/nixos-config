/*
  workstation/packages.nix — System packages, fonts, environment, and Docker.

  Package groups
  --------------
  Audio       EasyEffects (DSP), PavuControl (mixer), Helvum (graph).
  Browser     Firefox.
  Terminal    Kitty (GPU-accelerated, uses Nerd Font glyphs).
  Wayland     Core capture/clipboard utilities. Hyprland UI applications are
              versioned by Home Manager from unstable or dedicated flakes.
              grim + slurp (screenshots).
  System      Monitoring (btop, htop), file tools (tree), networking (iputils),
              hardware inspection (usbutils, i2c-tools).
  Build       GCC, GNU Make, Binutils, Python 3 (for build scripts/plugins).
  RGB         OpenRGB CLI for LED control.
  Containers  docker-compose (daemon managed by virtualisation.docker below).

  Docker
  ------
  Enabled system-wide with weekly image/container pruning.
  User "main" is added to the docker group in configuration.nix.

  Environment
  -----------
  NIXOS_OZONE_WL=1 enables the native Wayland backend for Chromium/Electron
  applications (VSCode, etc.), eliminating XWayland blurriness.
*/
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Audio
    easyeffects
    pavucontrol
    helvum

    # Browser & terminal are installed via Home Manager
    # (modules/home/firefox.nix, modules/home/kitty.nix).
    # Waybar is also HM-managed (modules/home/waybar.nix).

    # Wayland / desktop
    cliphist
    wl-clipboard
    wl-gammarelay-rs
    swayosd
    libnotify
    ddcutil
    grim
    slurp

    # System utilities
    git
    wget
    curl
    fastfetch
    starship
    htop
    btop
    tree
    usbutils
    i2c-tools
    iputils

    # Build tools
    gnumake
    gcc
    binutils
    python3

    # RGB
    openrgb

    # Storage tools
    btrfs-progs
    smartmontools

    # Containers
    docker-compose
  ];

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    font-awesome
    nerd-fonts.jetbrains-mono
  ];

  virtualisation.docker = {
    enable = true;
    package = pkgs.docker_29;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };

    # BuildKit + overlay2 + capped JSON logs.
    #   features.buildkit  Modern build engine: parallel + cache-mount +
    #                      secret-mount, big speed win for multi-stage builds.
    #   log-opts           Cap per-container logs at 3×10 MB — no more
    #                      runaway logs from a crash-looping container.
    #   storage-driver     overlay2 is the default; being explicit stops
    #                      Docker from probing at startup.
    daemon.settings = {
      features.buildkit = true;
      storage-driver = "overlay2";
      log-driver = "json-file";
      log-opts = {
        max-size = "10m";
        max-file = "3";
      };
    };
  };
}
