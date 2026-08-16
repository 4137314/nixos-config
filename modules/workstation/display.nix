/*
  workstation/display.nix — Display manager and XDG portal configuration.

  Display manager
  ---------------
  Ly is a lightweight TUI login manager written in C.
  The "matrix" animation plays on the login screen.

  XDG portals
  -----------
  The pathsToLink entries expose desktop portal backends (file picker,
  screenshot, screen cast) to Hyprland and other Wayland compositors.
  Without these symlinks, portal discovery via D-Bus may silently fail.
*/
_:
{
  services.displayManager.ly = {
    enable   = true;
    settings = {
      animation = "matrix";
      save      = true;
    };
  };

  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];
}
