/*
  home/kitty.nix — Kitty terminal emulator, declaratively configured.

  Font
  ----
  JetBrainsMono Nerd Font — installed system-wide in modules/workstation/
  packages.nix (fonts.packages). Ligatures on.

  Theme
  -----
  Catppuccin Mocha built-in preset. Change by picking any file under
  ${pkgs.kitty-themes}/share/kitty-themes/themes and swapping the includeFile.

  Behaviour
  ---------
  Confirm-on-quit only when there are multiple tabs open.
  Copy-on-select disabled — explicit Ctrl+Shift+C only, avoids accidental
  overwrite of the clipboard during long tmux copy sessions.

  Bindings kept minimal: keep muscle memory from stock kitty.
*/
{ config, ... }:
let
  t = config.myTheme;
in
{
  programs.kitty = {
    enable = true;
    themeFile = "Catppuccin-Mocha";

    font = {
      name = "JetBrainsMono Nerd Font";
      size = 11;
    };

    settings = {
      # Appearance
      window_padding_width = 8;
      hide_window_decorations = "yes";
      background_opacity = toString config.myTheme.opacity.terminal;
      dynamic_background_opacity = true;
      foreground = t.fg;
      background = t.base;
      cursor = t.accent;
      cursor_text_color = t.base;
      selection_foreground = t.base;
      selection_background = t.accent;
      active_border_color = t.accent;
      inactive_border_color = t.fgDim;
      cursor_shape = "beam";
      cursor_blink_interval = 0;
      scrollback_lines = 100000;
      scrollback_pager = "bat --paging=always --style=plain";

      # Behaviour
      confirm_os_window_close = 1;
      copy_on_select = "no";
      strip_trailing_spaces = "smart";
      enable_audio_bell = "no";
      visual_bell_duration = "0.1";
      shell_integration = "enabled no-title";

      # Tabs
      tab_bar_edge = "top";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
      tab_bar_background = t.base;
      active_tab_foreground = t.base;
      active_tab_background = t.accent;
      inactive_tab_foreground = t.fgDim;
      inactive_tab_background = t.surface;

      # URL handling
      url_style = "curly";
      detect_urls = "yes";

      # Wayland-native, no XWayland fallback (matches Hyprland).
      linux_display_server = "wayland";
    };

    keybindings = {
      "ctrl+shift+enter" = "new_window_with_cwd";
      "ctrl+shift+t" = "new_tab_with_cwd";
      "ctrl+shift+f" = "launch --stdin-source=@screen_scrollback --type=overlay less";
      "ctrl+shift+j" = "scroll_to_prompt -1";
      "ctrl+shift+k" = "scroll_to_prompt 1";
      "ctrl+shift+g" = "show_last_command_output";
      "ctrl+shift+u" = "kitten unicode_input";
    };
  };
}
