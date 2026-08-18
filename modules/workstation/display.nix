/*
  workstation/display.nix — Display manager, Wayland session, and XDG portals.

  Display manager
  ---------------
  Ly is a lightweight TUI login manager written in C.
  The "matrix" animation plays on the login screen.

  Hyprland at the system level
  ----------------------------
  `programs.hyprland.enable` installs the Wayland session file at
  /run/current-system/sw/share/wayland-sessions/hyprland.desktop and
  wires the required XDG portal backend (xdg-desktop-portal-hyprland).
  Without this, Ly cannot discover Hyprland at the greeter because it
  scans system session directories BEFORE any user profile is loaded.

  The Home Manager module (modules/home/hyprland.nix) still owns the
  user configuration (plugins, keybindings, native hyprland.conf).
  Both modules must point at the same package to avoid store conflicts —
  the system-level default and pkgs.hyprland in Home Manager match.

  XDG portals
  -----------
  pathsToLink exposes desktop portal backends (file picker, screenshot,
  screen cast) and the wayland-sessions directory so Ly can enumerate
  compositors. Without these symlinks, portal discovery via D-Bus and
  session listing at the greeter both silently fail.
*/
{ pkgs, ... }:
{
  services.displayManager.ly = {
    enable = true;
    settings = {
      animation = "matrix";
      save = true;
    };
  };

  # System-level Hyprland: installs the session file consumed by Ly and
  # sets up XDG portals + polkit agent required by a Wayland compositor.
  # UWSM is intentionally NOT enabled — it conflicts with the user-managed
  # hyprland-session.target that Home Manager already wires up via exec-once.
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Portal backends. programs.hyprland pulls in xdg-desktop-portal-hyprland,
  # gtk is added for GTK apps (file pickers etc).
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
    "/share/wayland-sessions"
    "/share/xsessions"
  ];
}
