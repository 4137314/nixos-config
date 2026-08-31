/*
  home/hyprlock.nix — Lock screen configuration.

  Cyberpunk palette pulled from `myTheme.*`. Big clock, date, dim
  blurred wallpaper background, neon accent input ring.

  Bound to SUPER+CTRL+L in hyprland.conf. Also triggered on lid close and
  after 5 min idle by hypridle (below).
*/
{
  config,
  lib,
  unstable,
  ...
}:
let
  t = config.myTheme;
  # Hyprlock accepts `rgb(RRGGBB)` and `rgba(R,G,B,A)` (0-255).
  # For neon accents we use rgb() so intensity stays full.
  toRgb = hex: "rgb(${lib.removePrefix "#" hex})";
in
{
  home.packages = [ unstable.hypridle ];

  programs.hyprlock = {
    enable = true;
    package = unstable.hyprlock;
    settings = {
      general = {
        disable_loading_bar = true;
        hide_cursor = true;
        grace = 3;
        no_fade_in = false;
      };

      background = [
        {
          path = "screenshot";
          blur_passes = 4;
          blur_size = 10;
          contrast = 1.05;
          brightness = 0.55;
          vibrancy = 0.22;
          vibrancy_darkness = 0.3;
        }
      ];

      input-field = [
        {
          size = "280, 46";
          outline_thickness = 2;
          dots_size = 0.3;
          dots_spacing = 0.3;
          outer_color = toRgb t.accent;
          inner_color = toRgb t.base;
          font_color = toRgb t.fg;
          check_color = toRgb t.accentSecondary;
          fail_color = toRgb t.danger;
          fade_on_empty = false;
          placeholder_text = "<span foreground='##${lib.removePrefix "#" t.fgDim}'><i>identity…</i></span>";
          hide_input = false;
          rounding = 4;
          position = "0, -90";
          halign = "center";
          valign = "center";
        }
      ];

      label = [
        # Operations banner
        {
          text = "NIXOS HACKER BOX";
          color = toRgb t.accentSecondary;
          font_size = 18;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 360";
          halign = "center";
          valign = "center";
        }
        # Big clock
        {
          text = ''cmd[update:1000] echo "<span font_weight='bold'>$(date +"%H:%M:%S")</span>"'';
          color = toRgb t.accent;
          font_size = 96;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 240";
          halign = "center";
          valign = "center";
        }
        # Date
        {
          text = ''cmd[update:60000] date "+%A, %-d %B %Y"'';
          color = toRgb t.fg;
          font_size = 22;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 140";
          halign = "center";
          valign = "center";
        }
        # Hostname@user prompt
        {
          text = ''cmd[update:0] echo "$USER@$(hostname)"'';
          color = toRgb t.accentSecondary;
          font_size = 16;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, -30";
          halign = "center";
          valign = "center";
        }
        # System stats footer (uptime + load)
        {
          text = ''cmd[update:5000] echo " $(uptime -p | sed 's/up //')   $(cat /proc/loadavg | awk '{print $1" "$2" "$3}')"'';
          color = toRgb t.fgDim;
          font_size = 12;
          font_family = "JetBrainsMono Nerd Font";
          position = "20, 20";
          halign = "left";
          valign = "bottom";
        }
        # Critical service status
        {
          text = ''cmd[update:5000] sh -lc 'printf "sshd:%s  f2b:%s  ts:%s  tor:%s" "$(systemctl is-active sshd.service 2>/dev/null || echo off)" "$(systemctl is-active fail2ban.service 2>/dev/null || echo off)" "$(systemctl is-active tailscaled.service 2>/dev/null || echo off)" "$(systemctl is-active tor.service 2>/dev/null || echo off)"' '';
          color = toRgb t.good;
          font_size = 12;
          font_family = "JetBrainsMono Nerd Font";
          position = "-20, 20";
          halign = "right";
          valign = "bottom";
        }
      ];
    };
  };

  services.hypridle = {
    enable = true;
    # The unmanaged native config starts hypridle once. Keep HM responsible
    # for its config while avoiding a second daemon from the user unit.
    package = null;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };

      listener = [
        {
          timeout = 300;
          on-timeout = "brightnessctl -s set 10%";
          on-resume = "brightnessctl -r";
        }
        {
          timeout = 330;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 600;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 1800;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };
}
