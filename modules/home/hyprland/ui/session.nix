/*
  home/hyprland/ui/session.nix — Modern session actions and desktop helpers.

  Adds a safe power menu, annotated screenshots, region recording, colour
  picking, notification bindings, NetworkManager tray and the native Hyprland
  polkit agent. Bind overrides are appended after the unmanaged native file.
*/
{
  config,
  inputs,
  lib,
  pkgs,
  unstable,
  ...
}:
let
  t = config.myTheme;
  inherit (pkgs.stdenv.hostPlatform) system;
  hyprlandPackage = inputs.hyprland.packages.${system}.hyprland;

  hexByte =
    color: offset:
    toString (lib.fromHexString (builtins.substring offset 2 (lib.removePrefix "#" color)));
  rgba =
    color: alpha: "rgba(${hexByte color 0}, ${hexByte color 2}, ${hexByte color 4}, ${toString alpha})";

  screenshot = pkgs.writeShellApplication {
    name = "hb-screenshot";
    runtimeInputs = [
      hyprlandPackage
      pkgs.coreutils
      pkgs.grim
      pkgs.jq
      pkgs.libnotify
      pkgs.slurp
      pkgs.wl-clipboard
      unstable.satty
    ];
    text = ''
      mode="''${1:-region}"
      output_dir="$HOME/Pictures/Screenshots"
      output_file="$output_dir/matrix-%Y-%m-%d_%H-%M-%S.png"
      mkdir -p "$output_dir"

      annotate() {
        satty \
          --filename - \
          --output-filename "$output_file" \
          --copy-command wl-copy \
          --initial-tool arrow \
          --early-exit
      }

      case "$mode" in
        region)
          geometry=$(slurp -d -c '#00ffffcc' -b '#07090fcc' || true)
          [ -n "$geometry" ] || exit 0
          grim -t ppm -g "$geometry" - | annotate
          ;;
        window)
          geometry=$(hyprctl activewindow -j \
            | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
          [ -n "$geometry" ] || exit 0
          grim -t ppm -g "$geometry" - | annotate
          ;;
        output)
          grim -t ppm - | annotate
          ;;
        *)
          notify-send "Screenshot" "mode: region | window | output"
          ;;
      esac
    '';
  };

  colourPicker = pkgs.writeShellApplication {
    name = "hb-colour-picker";
    runtimeInputs = [
      unstable.hyprpicker
      pkgs.libnotify
      pkgs.wl-clipboard
    ];
    text = ''
      colour=$(hyprpicker -f hex || true)
      [ -n "$colour" ] || exit 0
      printf '%s' "$colour" | wl-copy
      notify-send -t 1800 "Colour copied" "$colour"
    '';
  };

  recorder = pkgs.writeShellApplication {
    name = "hb-screen-record";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.libnotify
      pkgs.procps
      pkgs.slurp
      unstable.wf-recorder
    ];
    text = ''
      state_dir="''${XDG_RUNTIME_DIR:-/tmp}/hb-screen-record"
      pid_file="$state_dir/pid"
      output_dir="$HOME/Videos/Captures"
      mkdir -p "$state_dir" "$output_dir"

      if [ -r "$pid_file" ]; then
        recorder_pid=$(cat "$pid_file")
        if kill -0 "$recorder_pid" 2>/dev/null; then
          kill -INT "$recorder_pid"
          notify-send -t 1800 "Capture saved" "$output_dir"
          exit 0
        fi
        rm -f "$pid_file"
      fi

      geometry=$(slurp -d -c '#ff00ffcc' -b '#07090fcc' || true)
      [ -n "$geometry" ] || exit 0
      output_file="$output_dir/matrix-$(date +%Y-%m-%d_%H-%M-%S).mp4"

      cleanup() {
        rm -f "$pid_file"
      }
      trap cleanup EXIT

      wf-recorder -g "$geometry" -f "$output_file" &
      recorder_pid=$!
      printf '%s\n' "$recorder_pid" > "$pid_file"
      notify-send -t 1800 "Recording region" "SUPER+ALT+R to stop"
      wait "$recorder_pid"
    '';
  };

  sessionOverrides = ''
    # Modern session UI — appended after the unmanaged native configuration.
    unbind = SUPER, M
    bind = SUPER, M, exec, wlogout
    bind = SUPER SHIFT, M, exit

    unbind = , Print
    unbind = SHIFT, Print
    unbind = SUPER SHIFT, S
    bind = , Print, exec, hb-screenshot output
    bind = SHIFT, Print, exec, hb-screenshot region
    bind = CTRL, Print, exec, hb-screenshot window
    bind = SUPER SHIFT, S, exec, hb-screenshot region
    bind = SUPER SHIFT, C, exec, hb-colour-picker
    bind = SUPER ALT, R, exec, hb-screen-record
    bind = SUPER, comma, exec, swaync-client -t -sw

    # `togglesplit` became a layout message in Hyprland 0.54.
    unbind = SUPER, T
    unbind = SUPER CTRL, J
    bind = SUPER, T, layoutmsg, togglesplit
    bind = SUPER CTRL, J, layoutmsg, togglesplit

  '';
in
{
  home.packages = [
    screenshot
    colourPicker
    recorder
    unstable.brightnessctl
    unstable.playerctl
  ];

  programs.wlogout = {
    enable = true;
    package = unstable.wlogout;
    layout = [
      {
        label = "lock";
        action = "loginctl lock-session";
        text = "󰌾  LOCK";
        keybind = "l";
      }
      {
        label = "logout";
        action = "hyprctl dispatch exit";
        text = "󰍃  LOGOUT";
        keybind = "e";
      }
      {
        label = "suspend";
        action = "systemctl suspend";
        text = "󰤄  SUSPEND";
        keybind = "u";
      }
      {
        label = "reboot";
        action = "systemctl reboot";
        text = "󰜉  REBOOT";
        keybind = "r";
      }
      {
        label = "shutdown";
        action = "systemctl poweroff";
        text = "󰐥  SHUTDOWN";
        keybind = "s";
      }
    ];
    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 16px;
        font-weight: 800;
      }
      window {
        background: ${rgba t.base 0.86};
      }
      button {
        color: ${t.fg};
        background: ${rgba t.surface 0.80};
        border: 1px solid ${rgba t.accent 0.35};
        border-radius: 10px;
        margin: 18px;
        min-width: 190px;
        min-height: 150px;
        transition: all 160ms ease;
      }
      button:focus,
      button:hover {
        color: ${t.base};
        background: ${t.accent};
        border-color: ${t.accentSecondary};
        box-shadow: 0 0 28px ${rgba t.accent 0.50};
      }
      #shutdown:hover,
      #shutdown:focus {
        background: ${t.danger};
      }
      #suspend:hover,
      #suspend:focus {
        background: ${t.warn};
      }
    '';
  };

  services.hyprpolkitagent = {
    enable = true;
    package = unstable.hyprpolkitagent;
  };

  systemd.user.services.nm-applet = {
    Unit = {
      Description = "NetworkManager tray applet";
      After = [ "hyprland-session.target" ];
      PartOf = [ "hyprland-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = "${unstable.networkmanagerapplet}/bin/nm-applet --indicator";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "hyprland-session.target" ];
  };

  wayland.windowManager.hyprland.extraConfig = lib.mkAfter sessionOverrides;
}
