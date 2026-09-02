/*
  home/wofi.nix — Wofi application launcher.

  Invoked exclusively through `hb-wofi <mode>` (see modules/home/hyprland/
  default.nix), which guards single-instance behaviour and toggles the
  visible launcher on SUPER+R / SUPER+D. Palette pulled from `myTheme.*`
  so the launcher matches the rest of the desk visual identity.
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
      prompt = "▶";
      key_expand = "Tab";
      lines = 10;
      columns = 1;
      width = 680;
      height = 460;
      location = "center";
      hide_scroll = true;
      dynamic_lines = true;
      gtk_dark = true;
      # Terminal apps launched from drun open in plain kitty; hb-terminal
      # is reserved for the cockpit and does not accept a command argv.
      term = "kitty";
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 13px;
      }
      window {
        margin: 0;
        background-color: ${cssRgba t.surface t.opacity.launcher};
        border: 1px solid ${t.accent};
        border-radius: 6px;
        box-shadow: 0 0 24px ${cssRgba t.accent 0.35};
      }
      #input {
        margin: 10px 10px 6px 10px;
        padding: 8px 12px;
        border: none;
        border-radius: 4px;
        color: ${t.fg};
        background-color: ${cssRgba t.base 0.85};
        border-bottom: 2px solid ${t.accent};
        caret-color: ${t.accent};
      }
      #input:focus {
        outline: none;
        border-bottom-color: ${t.accentSecondary};
      }
      #inner-box, #outer-box { background-color: transparent; }
      #scroll { margin: 0 8px 6px 8px; }
      #entry {
        padding: 6px 12px;
        border-radius: 4px;
        color: ${t.fg};
      }
      #entry:selected {
        background-color: ${cssRgba t.accent 0.15};
        color: ${t.accent};
        border-left: 2px solid ${t.accent};
      }
      #entry image { margin-right: 10px; }
      #text { color: ${t.fg}; }
      #text:selected { color: ${t.accent}; font-weight: bold; }
      #unselected { color: ${t.fgDim}; }
    '';
  };
}
