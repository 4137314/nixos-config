/*
  home/hyprland/ui/default.nix — Session UI module tree.

  Notifications, session actions and toolkit theming are deliberately split
  so each surface can evolve without growing the compositor root module.
*/
_: {
  imports = [
    ./notifications.nix
    ./session.nix
    ./theme.nix
  ];
}
