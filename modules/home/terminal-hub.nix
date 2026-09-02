/*
  home/terminal-hub.nix — Terminal-first command palette and tmux telemetry.

  `hb-term` is the executable catalogue for the workstation's terminal tools.
  It launches each specialist TUI in the current directory and centralises
  navigation between the fixed tmux cockpit windows. Mutating NixOS operations
  are available here too, but require an explicit confirmation before they run.

  `hb-tmux-status` is a cached, low-cost status segment for tmux. It combines
  failed system/user units, firing Prometheus alerts and root filesystem usage
  without making every status refresh execute a full dashboard probe.
*/
{ pkgs, ... }:
let
  terminalHub = pkgs.writeShellApplication {
    name = "hb-term";
    runtimeInputs = with pkgs; [
      aichat
      bandwhich
      bash
      btop
      coreutils
      curl
      docker_29
      fd
      fzf
      gawk
      gdu
      git
      gnumake
      gnugrep
      gnused
      gum
      iproute2
      jq
      k9s
      kmon
      lazydocker
      lazygit
      lazysql
      less
      lnav
      mprocs
      navi
      ncdu
      neovim
      networkmanager
      nh
      nix
      nix-du
      nix-inspect
      nvd
      podman
      podman-tui
      posting
      procps
      rainfrog
      ripgrep
      serpl
      systemctl-tui
      systemd
      termshark
      tmux
      trippy
      util-linux
      yazi
      zsh
    ];
    text = builtins.readFile ./terminal-hub.sh;
  };

  # Real executable, not just a shell alias: works in existing shells, scripts
  # and tmux commands as soon as the Home Manager profile is activated.
  hubCommand = pkgs.writeShellApplication {
    name = "hub";
    runtimeInputs = [ terminalHub ];
    text = ''
      exec hb-term "$@"
    '';
  };

  tmuxStatus = pkgs.writeShellApplication {
    name = "hb-tmux-status";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gawk
      jq
      systemd
    ];
    text = builtins.readFile ./tmux-status.sh;
  };
in
{
  home.packages = [
    terminalHub
    hubCommand
    tmuxStatus

    # Specialist TUIs are also exposed directly in the interactive shell.
    pkgs.gdu
    pkgs.k9s
    pkgs.kmon
    pkgs.lazysql
    pkgs.podman-tui
    pkgs.rainfrog
    pkgs.serpl
    pkgs.termshark
  ];
}
