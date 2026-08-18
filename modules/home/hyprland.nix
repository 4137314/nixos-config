/*
  home/hyprland.nix — Hyprland Wayland compositor, managed by Home Manager.

  Native configuration
  --------------------
  The compositor is configured via the native `hyprland/hyprland.conf`
  file co-located with this module. Nix does not generate or overwrite
  it; it is loaded verbatim via `builtins.readFile` and streamed into
  Home Manager as `extraConfig`.

  Plugin: hyprexpo
  ----------------
  hyprexpo provides an Exposé-style overview of all workspaces. Because
  the plugin `.so` lives in the Nix store (unpredictable path), this
  module prepends a `$HYPREXPO_PATH` variable so `hyprland.conf` can
  reference the plugin symbolically instead of hard-coding a store path.

  settings = {}
  -------------
  Empty on purpose — otherwise Home Manager would generate a second
  hyprland.conf and the two would fight for precedence.
*/
{ pkgs, ... }:
let
  inherit (pkgs.hyprlandPlugins) hyprexpo;
  nativeConfig = builtins.readFile ./hyprland/hyprland.conf;
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    plugins = [ hyprexpo ];
    settings = { };
    extraConfig = ''
      $HYPREXPO_PATH = ${hyprexpo}/lib/libhyprexpo.so

      ${nativeConfig}
    '';
  };
}
