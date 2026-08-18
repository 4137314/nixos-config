/*
  home/tmux.nix — tmux terminal multiplexer.

  Layout defaults
  ---------------
  Prefix         Ctrl-a (easier reach than the default Ctrl-b)
  Base index     1 for windows and panes (matches keyboard layout)
  Mouse          Enabled — scroll, resize, and pane selection with the mouse
  Vi copy mode   `v` to start selection, `y` to copy to system clipboard
  Splits         `|` vertical, `-` horizontal — stay in the current directory

  Plugins
  -------
  tmux-sensible  Community-tested baseline settings
  vim-tmux-nav   Seamless Ctrl-h/j/k/l navigation with Vim/Neovim splits
  tmux-yank      System-clipboard integration for yanked text
  tmux-resurrect Save and restore sessions across reboots

  History and 256-colour terminal are set for long-running debug sessions
  (msfconsole, ncat, tail -F …) where scrollback is valuable.
*/
{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    prefix = "C-a";
    baseIndex = 1;
    mouse = true;
    keyMode = "vi";
    escapeTime = 10;
    historyLimit = 100000;
    terminal = "tmux-256color";
    aggressiveResize = true;

    plugins = with pkgs.tmuxPlugins; [
      sensible
      vim-tmux-navigator
      yank
      resurrect
    ];

    extraConfig = ''
      # True colour passthrough.
      set -ga terminal-overrides ",xterm-256color:Tc,alacritty:Tc,kitty:Tc"

      # Renumber windows when one is closed.
      set -g renumber-windows on

      # Splits keep the current path.
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # Reload config on the fly.
      bind r source-file ~/.config/tmux/tmux.conf \; display "reloaded"

      # Copy-mode: v to start, y to yank to clipboard.
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi y send -X copy-pipe-and-cancel "wl-copy"

      # Status bar — minimal, informative.
      set -g status-position bottom
      set -g status-style "bg=default fg=white"
      set -g status-left  "#[fg=green,bold]#S "
      set -g status-right "#[fg=yellow]%Y-%m-%d #[fg=cyan]%H:%M "
      set -g status-left-length 40
    '';
  };
}
