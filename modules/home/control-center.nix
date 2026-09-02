/*
  home/control-center.nix — Central read-only operations TUI.

  `hb-control-center` is the terminal counterpart to the compact Waybar
  indicators. It brings host health, Prometheus alerts, persistent journal
  views, NixOS generations, timers, storage, networking, containers and agent
  state into one searchable fzf interface. Detailed logs open in lnav, while
  specialist tools such as systemctl-tui, lazydocker and btop remain one key
  press away.

  Health views intentionally do not mutate services or the NixOS
  configuration. The first menu entry opens `hb-term`, where administrative
  actions and specialist TUIs are centralised with explicit confirmations.
*/
{ pkgs, ... }:
let
  controlCenter = pkgs.writeShellApplication {
    name = "hb-control-center";
    runtimeInputs = with pkgs; [
      btop
      coreutils
      curl
      docker_29
      fzf
      gawk
      git
      gnugrep
      gnused
      iproute2
      jq
      lazydocker
      less
      libvirt
      lnav
      lm_sensors
      nvd
      podman
      procps
      ripgrep
      systemctl-tui
      systemd
      tailscale
      util-linux
    ];
    text = builtins.readFile ./control-center.sh;
  };

  # Keep the short operator command available outside interactive shell alias
  # expansion as well (tmux, scripts and shells opened before activation).
  controlCommand = pkgs.writeShellApplication {
    name = "control";
    runtimeInputs = [ controlCenter ];
    text = ''
      exec hb-control-center "$@"
    '';
  };
in
{
  home.packages = [
    controlCenter
    controlCommand
  ];
}
