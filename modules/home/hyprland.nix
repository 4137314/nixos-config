/*
  home/hyprland.nix — Hyprland Wayland compositor, managed by Home Manager.

  Native configuration
  --------------------
  The compositor is configured via the native hyprland.conf file at the
  repository root. Nix does not generate or overwrite this file; it is
  loaded verbatim via `builtins.readFile`.

  Plugin: hyprexpo
  ----------------
  hyprexpo provides an Exposé-style overview of all workspaces.
  Because the plugin .so path lives in the Nix store (not a predictable
  system path), this module injects $HYPREXPO_PATH before the native
  config so that the HYPR_PLUGIN_PATH line in hyprland.conf can reference
  it with `$HYPREXPO_PATH` instead of a hard-coded store path.

  settings = {}
  -------------
  Prevents Home Manager from generating a duplicate hyprland.conf that
  would conflict with the one injected via extraConfig.
*/
{ pkgs, ... }:
{
  wayland.windowManager.hyprland = {
    enable  = true;
    package = pkgs.hyprland;

    plugins = [
      pkgs.hyprlandPlugins.hyprexpo
    ];

    settings = { };

    extraConfig = ''
      $HYPREXPO_PATH = ${pkgs.hyprlandPlugins.hyprexpo}/lib/libhyprexpo.so

      ${builtins.readFile ../../hyprland.conf}
    '';
  };
}
