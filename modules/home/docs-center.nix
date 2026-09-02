/*
  home/docs-center.nix — Live documentation and keymap TUI.

  `hb-docs` is the read-only knowledge surface for the terminal cockpit. It
  reads the actual tmux server, Hyprland IPC state, Pi JSON configuration and
  this flake instead of maintaining a second hand-written source of truth.
  The short `docs` executable works outside interactive shell alias expansion.
*/
{ inputs, pkgs, ... }:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  hyprlandPackage = inputs.hyprland.packages.${system}.hyprland;

  docsCenter = pkgs.writeShellApplication {
    name = "hb-docs";
    runtimeInputs = with pkgs; [
      bash
      bat
      coreutils
      fd
      findutils
      fzf
      gawk
      git
      glow
      gnugrep
      gnused
      gum
      jq
      less
      man
      man-db
      neovim
      nix
      nixos-option
      ripgrep
      tealdeer
      tmux
      util-linux
      hyprlandPackage
    ];
    text = builtins.readFile ./docs-center.sh;
  };

  docsCommand = pkgs.writeShellApplication {
    name = "docs";
    runtimeInputs = [ docsCenter ];
    text = ''
      exec hb-docs "$@"
    '';
  };
in
{
  home.packages = [
    docsCenter
    docsCommand
  ];
}
