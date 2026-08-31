/*
  home/hyprland/ui/theme.nix — Toolkit, icons and cursor integration.

  Gives GTK/Qt applications the same dark glass baseline as the compositor
  and installs a proper Hyprcursor-compatible pointer through Home Manager.
*/
{ pkgs, unstable, ... }:
{
  home.pointerCursor = {
    package = unstable.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  gtk = {
    enable = true;
    theme = {
      package = unstable.adw-gtk3;
      name = "adw-gtk3-dark";
    };
    iconTheme = {
      package = unstable.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    font = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font";
      size = 11;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    cursor-theme = "Bibata-Modern-Ice";
    icon-theme = "Papirus-Dark";
  };
}
