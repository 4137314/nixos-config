{ pkgs, ... }:

# ─────────────────────────────────────────────────────────────────────────────
# Pacchetti di sistema, font, variabili d'ambiente e virtualizzazione.
# ─────────────────────────────────────────────────────────────────────────────
{
  environment.systemPackages = with pkgs; [
    # ── Audio ────────────────────────────────────────────────────────────────
    easyeffects pavucontrol helvum

    # ── Browser & terminale ──────────────────────────────────────────────────
    kitty firefox

    # ── Wayland / Desktop ────────────────────────────────────────────────────
    wofi cliphist wl-clipboard swww libnotify
    ddcutil waybar hyprlock hypridle wl-gammarelay-rs swayosd

    # ── Utility di sistema ───────────────────────────────────────────────────
    git wget curl fastfetch starship
    htop btop tree
    usbutils i2c-tools iputils

    # ── Build tools ──────────────────────────────────────────────────────────
    gnumake gcc binutils python3

    # ── RGB ──────────────────────────────────────────────────────────────────
    openrgb

    # ── Container ────────────────────────────────────────────────────────────
    docker-compose
  ];

  # Wayland nativo per app Electron/Chromium (VSCode, ecc.)
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # ── Font ──────────────────────────────────────────────────────────────────
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    font-awesome
    nerd-fonts.jetbrains-mono
  ];

  # ── Docker ────────────────────────────────────────────────────────────────
  virtualisation.docker = {
    enable    = true;
    autoPrune = {
      enable = true;
      dates  = "weekly";
    };
  };
}
