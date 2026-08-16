{ pkgs, ... }:

# ─────────────────────────────────────────────────────────────────────────────
# Hyprland: window manager Wayland.
# La configurazione nativa è in /etc/nixos/hyprland.conf (non modificata da Nix).
# Qui iniettiamo solo il path del plugin hyprexpo nello store Nix.
# ─────────────────────────────────────────────────────────────────────────────
{
  wayland.windowManager.hyprland = {
    enable  = true;
    package = pkgs.hyprland;

    plugins = [
      pkgs.hyprlandPlugins.hyprexpo
    ];

    # settings = {} previene la generazione di un hyprland.conf duplicato da HM
    settings = {};

    # Inietta il path reale di hyprexpo nel Nix Store,
    # poi include il file hyprland.conf nativo senza modificarlo.
    extraConfig = ''
      $HYPREXPO_PATH = ${pkgs.hyprlandPlugins.hyprexpo}/lib/libhyprexpo.so

      ${builtins.readFile ../hyprland.conf}
    '';
  };
}
