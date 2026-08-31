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

  Pi compatibility
  ----------------
  Extended keys use CSI-u so Pi can distinguish Enter, Shift+Enter,
  Ctrl+Enter and Alt+Enter even inside tmux.

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
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
        '';
      }
    ];

    extraConfig = ''
      # True colour passthrough.
      set -ga terminal-overrides ",xterm-256color:Tc,alacritty:Tc,kitty:Tc"
      set -as terminal-features ",xterm-256color:RGB,kitty:RGB"

      # Pi / modern TUI input fidelity in tmux >= 3.5.
      set -g extended-keys on
      set -g extended-keys-format csi-u
      set -g allow-passthrough on
      set -g focus-events on
      set -g set-clipboard on

      # Renumber windows when one is closed.
      set -g renumber-windows on
      set -g detach-on-destroy off
      set -g display-time 1500
      set -g repeat-time 400
      bind C-a send-prefix

      # Splits keep the current path.
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"
      bind '"' split-window -v -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"

      # Pane movement and resizing stay under the prefix, Vim-style.
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 3
      bind -r K resize-pane -U 3
      bind -r L resize-pane -R 5

      # Operator popups.
      bind p display-popup -d /etc/nixos -w 90% -h 85% -E 'pi --agent hacker-box --name hacker-box'
      bind g display-popup -d "#{pane_current_path}" -w 90% -h 85% -E lazygit
      bind b display-popup -w 90% -h 85% -E btop
      bind D display-popup -d "#{pane_current_path}" -w 95% -h 90% -E lazydocker
      bind S display-popup -w 95% -h 90% -E systemctl-tui

      # Reload config on the fly.
      bind r source-file ~/.config/tmux/tmux.conf \; display "reloaded"

      # Copy-mode: v to start, y to yank to clipboard.
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi y send -X copy-pipe-and-cancel "wl-copy"

      # Status bar — neon cyberpunk theme.
      set -g status-position bottom
      set -g status-interval 5
      set -g status-justify centre
      set -g status-style "bg=default fg=#768096"
      set -g status-left  "#[fg=#00ffff,bold] #S #[fg=#768096]│ #[fg=#d7e2ff]#W "
      set -g status-right "#{?client_prefix,#[bg=#ff00ff,fg=#07090f,bold] ⌨ #[default] ,}#[fg=#ffb000]%H:%M #[fg=#768096]│ #[fg=#00ff88]#H "
      set -g status-left-length 60
      set -g status-right-length 60
      setw -g window-status-format "#[fg=#768096] #I:#W "
      setw -g window-status-current-format "#[bg=#00ffff,fg=#07090f,bold] #I:#W #[default]"
      set -g pane-border-style "fg=#1e2a3a"
      set -g pane-active-border-style "fg=#00ffff"
      set -g message-style "bg=#1e2a3a fg=#00ffff bold"

      # Toggle mouse, open yazi / fzf session picker.
      bind M set -g mouse \; display "mouse: #{?mouse,on,off}"
      bind e display-popup -d "#{pane_current_path}" -w 90% -h 85% -E yazi
      bind f display-popup -d "#{pane_current_path}" -w 60% -h 40% -E \
        'session=$(tmux list-sessions -F "#S" | fzf --prompt="session › " --height=100%) && tmux switch-client -t "$session"'

      # Alt+1..9 — jump to window N without prefix.
      bind -n M-1 select-window -t :1
      bind -n M-2 select-window -t :2
      bind -n M-3 select-window -t :3
      bind -n M-4 select-window -t :4
      bind -n M-5 select-window -t :5
      bind -n M-6 select-window -t :6
      bind -n M-7 select-window -t :7
      bind -n M-8 select-window -t :8
      bind -n M-9 select-window -t :9

      # Claude Code popup — prefix+C (capital C to avoid conflict with new-window).
      bind C display-popup -d "#{pane_current_path}" -w 95% -h 90% -E 'claude'
      bind O display-popup -d "#{pane_current_path}" -w 95% -h 90% -E 'codex'

      # 2026 smart-shell popups.
      # prefix+a → aichat scratch (local Ollama by default).
      # prefix+n → nh os switch (modern rebuild wrapper — asks for sudo).
      # prefix+h → helix quick edit rooted in the current pane path.
      # prefix+t → mprocs task runner (uses mprocs.yaml if present).
      # prefix+P → posting HTTP TUI.
      bind a display-popup -d "#{pane_current_path}" -w 90% -h 85% -E 'aichat'
      bind n display-popup -d /etc/nixos              -w 90% -h 85% -E 'make switch'
      bind h display-popup -d "#{pane_current_path}" -w 95% -h 90% -E 'hx .'
      bind t display-popup -d "#{pane_current_path}" -w 95% -h 90% -E 'mprocs'
      bind P display-popup -d "#{pane_current_path}" -w 95% -h 90% -E 'posting'

      # Session restore.
      set -g @resurrect-capture-pane-contents 'on'
      set -g @resurrect-strategy-nvim 'session'
    '';
  };
}
