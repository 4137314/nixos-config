/*
  home/wofi.nix — Wofi application launcher configuration.

  Bound to SUPER+R in hyprland.conf. Uses a Catppuccin Mocha style that
  matches Kitty and Waybar. Search is fuzzy, results ranked by frecency.
*/
_: {
  programs.wofi = {
    enable = true;

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
      width = 600;
      location = "center";
    };

    style = ''
      window {
        margin: 0;
        background-color: rgba(30, 30, 46, 0.92);
        border: 2px solid #33ccff;
        border-radius: 10px;
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 13px;
      }
      #input {
        margin: 8px;
        padding: 6px 10px;
        border: none;
        border-radius: 6px;
        color: #cdd6f4;
        background-color: #1e1e2e;
      }
      #input:focus {
        outline: none;
        box-shadow: 0 0 0 1px #33ccff;
      }
      #inner-box, #outer-box {
        background-color: transparent;
      }
      #scroll { margin: 0 8px; }
      #entry { padding: 6px 10px; border-radius: 6px; }
      #entry:selected {
        background-color: rgba(51, 204, 255, 0.15);
        color: #33ccff;
      }
      #text { color: #cdd6f4; }
    '';
  };
}
