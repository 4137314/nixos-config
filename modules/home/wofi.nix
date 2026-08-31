/*
  home/wofi.nix — Wofi application launcher.

  Bound to SUPER+R in hyprland.conf. Palette pulled from `myTheme.*`,
  matches the Waybar / Kitty / Hyprland accent.
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
    hex: offset: toString (lib.fromHexString (builtins.substring offset 2 (lib.removePrefix "#" hex)));
  cssRgba =
    hex: alpha: "rgba(${hexByte hex 0}, ${hexByte hex 2}, ${hexByte hex 4}, ${toString alpha})";
in
{
  programs.wofi = {
    enable = true;
    package = unstable.wofi;

    settings = {
      allow_markup = true;
      allow_images = true;
      image_size = 32;
      matching = "fuzzy";
      insensitive = true;
      no_actions = true;
      prompt = "run";
      key_expand = "Tab";
      lines = 8;
      width = 640;
      location = "center";
    };

    style = ''
      window {
        margin: 0;
        background-color: ${cssRgba t.surface t.opacity.launcher};
        border: 1px solid ${t.accent};
        border-radius: 4px;
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 13px;
      }
      #input {
        margin: 8px;
        padding: 8px 12px;
        border: none;
        border-radius: 3px;
        color: ${t.fg};
        background-color: ${cssRgba t.base 0.8};
        border-bottom: 2px solid ${t.accent};
      }
      #input:focus {
        outline: none;
        border-bottom-color: ${t.accentSecondary};
      }
      #inner-box, #outer-box { background-color: transparent; }
      #scroll { margin: 0 8px; }
      #entry {
        padding: 6px 10px;
        border-radius: 3px;
        color: ${t.fg};
      }
      #entry:selected {
        background-color: ${cssRgba t.accent 0.15};
        color: ${t.accent};
        border-left: 2px solid ${t.accent};
      }
      #text { color: ${t.fg}; }
      #text:selected { color: ${t.accent}; }
    '';
  };
}
