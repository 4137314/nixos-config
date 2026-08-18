/*
  home/hyprlock.nix — Lock screen configuration.

  Matches the Kitty / Waybar / Wofi palette (Catppuccin Mocha + cyan
  accent). Shows: wallpaper (blurred), big clock, date, user avatar
  circle, password prompt with subtle animation.

  Bound to SUPER+L in hyprland.conf. Also triggered on lid close and
  after 5 min idle by hypridle (below).
*/
_: {
  programs.hyprlock = {
    enable = true;
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
          blur_passes = 3;
          blur_size = 6;
          contrast = 0.8916;
          brightness = 0.65;
          vibrancy = 0.16;
        }
      ];

      input-field = [
        {
          size = "260, 44";
          outline_thickness = 2;
          dots_size = 0.3;
          dots_spacing = 0.25;
          outer_color = "rgb(33ccff)";
          inner_color = "rgb(1e1e2e)";
          font_color = "rgb(cdd6f4)";
          fade_on_empty = false;
          placeholder_text = "<span foreground='##a6adc8'><i>password…</i></span>";
          hide_input = false;
          rounding = 10;
          position = "0, -80";
          halign = "center";
          valign = "center";
        }
      ];

      label = [
        {
          text = ''cmd[update:1000] echo "<span font_weight='bold'>$(date +"%H:%M")</span>"'';
          color = "rgba(205,214,244,0.95)";
          font_size = 100;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 220";
          halign = "center";
          valign = "center";
        }
        {
          text = ''cmd[update:60000] date "+%A, %-d %B %Y"'';
          color = "rgba(166,173,200,0.9)";
          font_size = 20;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 130";
          halign = "center";
          valign = "center";
        }
        {
          text = "$USER";
          color = "rgba(166,173,200,0.9)";
          font_size = 16;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, -30";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };

  services.hypridle = {
    enable = true;
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
