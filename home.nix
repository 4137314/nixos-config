/*
  home.nix — Home Manager entry point for user "main".

  All user-space configuration is delegated to the sub-modules under
  modules/home/. This file only sets the identity attributes required by
  Home Manager (username, home directory, state version).
*/
_:
{
  imports = [
    ./modules/home/packages.nix
    ./modules/home/vscode.nix
    ./modules/home/hyprland.nix
    ./modules/home/neovim.nix
  ];

  home = {
    username      = "main";
    homeDirectory = "/home/main";
    stateVersion  = "25.11";
  };
}
