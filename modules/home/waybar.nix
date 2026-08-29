/*
  home/waybar.nix — Waybar status bar for Hyprland.

  Layout
  ------
  Left    workspaces
  Center  window title
  Right   network · pulseaudio · cpu · memory · disk · temp · clock · tray

  Style
  -----
  Dark, minimal, matches the Hyprland `col.active_border` cyan/green accent.
  Uses JetBrainsMono Nerd Font glyphs (already installed system-wide).
*/
_: {
  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      target = "hyprland-session.target";
    };

    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 32;
      margin-top = 4;
      margin-left = 8;
      margin-right = 8;
      spacing = 4;

      modules-left = [
        "hyprland/workspaces"
        "hyprland/submap"
      ];
      modules-center = [ "hyprland/window" ];
      modules-right = [
        "network"
        "pulseaudio"
        "cpu"
        "memory"
        "temperature"
        "disk"
        "clock"
        "tray"
      ];

      "hyprland/workspaces" = {
        format = "{icon}";
        on-click = "activate";
        # Waybar priorities `active` / `urgent` / `default` OVER the
        # per-workspace icons when they are set — so having
        # `active = ""` (empty string) caused the number of the active
        # workspace to disappear entirely. Keep only the numeric map;
        # the active-state visual differentiation is handled purely in
        # CSS below (background + cyan text).
        format-icons = {
          "1" = "1";
          "2" = "2";
          "3" = "3";
          "4" = "4";
          "5" = "5";
          "6" = "6";
          "7" = "7";
          "8" = "8";
          "9" = "9";
          "10" = "10";
        };
      };

      "hyprland/window" = {
        format = "{}";
        max-length = 60;
        rewrite = {
          "(.*) - Mozilla Firefox" = " $1";
          "(.*) - VSCodium" = "󰨞 $1";
          "(.*) — Kitty" = " $1";
        };
      };

      network = {
        format-wifi = "  {essid} ({signalStrength}%)";
        format-ethernet = "󰈀 {ifname}";
        format-disconnected = "󰤭 offline";
        tooltip-format = "{ipaddr}/{cidr}\n {bandwidthDownBits}   {bandwidthUpBits}";
      };

      pulseaudio = {
        format = "{volume}% {icon}";
        format-muted = "  muted";
        format-icons = {
          default = [
            ""
            ""
            ""
          ];
        };
        on-click = "pavucontrol";
      };

      cpu = {
        format = "  {usage}%";
        interval = 2;
      };
      memory = {
        format = "  {used:0.1f}G/{total:0.1f}G";
        interval = 5;
      };
      temperature = {
        thermal-zone = 0;
        critical-threshold = 85;
        format = " {temperatureC}°C";
        format-critical = " {temperatureC}°C";
      };
      disk = {
        path = "/";
        format = "󰋊 {free}";
        interval = 30;
      };
      clock = {
        format-alt = "{:%A, %d %B %Y}";
        format = "  {:%H:%M}";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
      };
      tray = {
        icon-size = 18;
        spacing = 8;
      };
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free";
        font-size: 12px;
        border: none;
        border-radius: 0;
        min-height: 0;
      }
      window#waybar {
        background: rgba(20, 22, 30, 0.85);
        color: #cdd6f4;
        border-radius: 10px;
      }
      #workspaces button {
        padding: 0 8px;
        color: #6c7086;
        background: transparent;
      }
      #workspaces button.active {
        color: #33ccff;
        background: rgba(51, 204, 255, 0.1);
        border-radius: 6px;
      }
      #workspaces button.urgent {
        color: #f38ba8;
      }
      #window {
        color: #a6adc8;
        padding: 0 12px;
      }
      #network, #pulseaudio, #cpu, #memory, #disk, #temperature, #clock, #tray {
        padding: 0 10px;
        color: #cdd6f4;
      }
      #temperature.critical {
        color: #f38ba8;
      }
    '';
  };
}
