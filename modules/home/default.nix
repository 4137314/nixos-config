/*
  home/default.nix — Home Manager entry point for user "main".

  All user-space configuration is delegated to the sub-modules in this
  directory. This file only sets the identity attributes required by
  Home Manager (username, home directory, state version).

  Imported by flake.nix via `users.main = import ./modules/home`.
*/
_: {
  imports = [
    ./theme.nix
    ./packages.nix
    ./vscode.nix
    ./hyprland.nix
    ./neovim.nix
    ./git.nix
    ./bash.nix
    ./tmux.nix
    ./ssh.nix
    ./cli-tools.nix
    ./kitty.nix
    ./firefox.nix
    ./waybar.nix
    ./wofi.nix
    ./hyprlock.nix
    ./wallpaper.nix
    ./zed.nix
    ./pi-agent.nix
    ./claude-code.nix
  ];

  home = {
    username = "main";
    homeDirectory = "/home/main";
    stateVersion = "25.11";
  };
}
