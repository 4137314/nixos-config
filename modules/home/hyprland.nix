/*
  home/hyprland.nix — Compatibility entry point for the Hyprland tree.

  The implementation lives under `home/hyprland/`: compositor core,
  parametric appearance, session UI and native configuration are separate
  concerns. Keep imports elsewhere stable by importing this small shim.
*/
_: {
  imports = [ ./hyprland/default.nix ];
}
