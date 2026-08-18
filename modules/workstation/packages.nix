/*
  workstation/packages.nix — System packages, fonts, environment, and Docker.

  Package groups
  --------------
  Audio       EasyEffects (DSP), PavuControl (mixer), Helvum (graph).
  Browser     Firefox.
  Terminal    Kitty (GPU-accelerated, uses Nerd Font glyphs).
  Wayland     Compositor utilities: Waybar, Hyprlock, Hypridle, Wofi, SWWW,
              cliphist, wl-clipboard, wl-gammarelay-rs, SwayOSD, ddcutil.
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
    hyprlock
    hypridle
    wofi
    swww
    cliphist
    wl-clipboard
    wl-gammarelay-rs
    swayosd
    libnotify
    ddcutil

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
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
}
