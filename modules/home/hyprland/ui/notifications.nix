/*
  home/hyprland/ui/notifications.nix — SwayNC notification center.

  GTK4 notification history, DND, media controls, volume/brightness sliders
  and a compact quick-action grid. Palette is shared with the rest of the UI.
*/
{
  config,
  lib,
  unstable,
  ...
}:
let
  t = config.myTheme;
  hexByte =
    color: offset:
    toString (lib.fromHexString (builtins.substring offset 2 (lib.removePrefix "#" color)));
  rgba =
    color: alpha: "rgba(${hexByte color 0}, ${hexByte color 2}, ${hexByte color 4}, ${toString alpha})";
in
{
  services.swaync = {
    enable = true;
    package = unstable.swaynotificationcenter;
    settings = {
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      "layer-shell" = true;
      "layer-shell-cover-screen" = true;
      cssPriority = "user";
      "control-center-layer" = "overlay";
      "control-center-margin-top" = 48;
      "control-center-margin-right" = 12;
      "control-center-margin-bottom" = 12;
      "control-center-width" = 430;
      "notification-window-width" = 430;
      "notification-body-image-height" = 160;
      "notification-body-image-width" = 300;
      "notification-2fa-action" = true;
      "notification-inline-replies" = true;
      "fit-to-screen" = false;
      "relative-timestamps" = true;
      timeout = 7;
      "timeout-low" = 4;
      "timeout-critical" = 0;

      widgets = [
        "title"
        "dnd"
        "mpris"
        "volume"
        "backlight"
        "buttons-grid#quick"
        "notifications"
      ];

      "widget-config" = {
        title = {
          text = "NEURAL FEED";
          "clear-all-button" = true;
          "button-text" = "CLEAR";
        };
        dnd.text = "DO NOT DISTURB";
        mpris = {
          "show-album-art" = "when-available";
          autohide = true;
          "loop-carousel" = true;
        };
        volume.label = "󰕾";
        backlight = {
          label = "󰃠";
          min = 5;
        };
        "buttons-grid#quick" = {
          "buttons-per-row" = 4;
          actions = [
            {
              label = "󰌾";
              command = "loginctl lock-session";
            }
            {
              label = "󰂛";
              command = "swaync-client -d";
            }
            {
              label = "󰑓";
              command = "hyprctl reload";
            }
            {
              label = "󰐥";
              command = "wlogout";
            }
          ];
        };
        notifications.vexpand = true;
      };
    };

    style = ''
      :root {
        --notification-icon-size: 54px;
        --notification-app-icon-size: 22px;
        --mpris-album-art-icon-size: 78px;
        --widget-volume-row-icon-size: 24px;
      }

      * {
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 12px;
        color: ${t.fg};
      }

      .notification-row,
      .notification-background {
        outline: none;
      }

      .notification {
        background: ${rgba t.surface 0.94};
        border: 1px solid ${rgba t.accent 0.48};
        border-radius: 8px;
        margin: 6px 10px;
        box-shadow: 0 10px 36px ${rgba t.base 0.72};
      }

      .notification.critical {
        border-color: ${rgba t.danger 0.85};
      }

      .notification-content {
        padding: 10px;
      }

      .summary {
        color: ${t.accent};
        font-weight: 800;
      }

      .time,
      .body {
        color: ${t.fgDim};
      }

      .control-center {
        background: ${rgba t.base 0.90};
        border: 1px solid ${rgba t.accentSecondary 0.55};
        border-radius: 10px;
        box-shadow: 0 18px 50px ${rgba t.base 0.82};
        padding: 10px;
      }

      .widget-title,
      .widget-dnd,
      .widget-mpris,
      .widget-volume,
      .widget-backlight,
      .widget-buttons-grid {
        background: ${rgba t.surface 0.72};
        border: 1px solid ${rgba t.accent 0.18};
        border-radius: 7px;
        margin: 5px;
        padding: 8px 10px;
      }

      .widget-title > label {
        color: ${t.accent};
        font-size: 14px;
        font-weight: 900;
        letter-spacing: 2px;
      }

      button {
        background: ${rgba t.base 0.64};
        border: 1px solid ${rgba t.accent 0.25};
        border-radius: 6px;
        color: ${t.fg};
        transition: all 120ms ease;
      }

      button:hover,
      button:checked {
        background: ${rgba t.accent 0.17};
        border-color: ${t.accent};
        color: ${t.accent};
      }

      trough {
        min-height: 6px;
        border-radius: 6px;
        background: ${rgba t.fgDim 0.25};
      }

      highlight {
        min-height: 6px;
        border-radius: 6px;
        background: ${t.accent};
      }
    '';
  };
}
