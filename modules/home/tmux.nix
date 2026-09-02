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
  tmux-cpu       CPU/RAM telemetry in the status bar
  prefix-highlight Visible prefix, copy-mode and synchronized-pane state
  extrakto       Fuzzy extraction of paths, hashes, URLs and visible text
  tmux-thumbs    Vimium-like hints for copying terminal tokens
  tmux-fzf       Unified session/window/pane/process manager
  tmux-sessionx  Project/session/window switcher with previews and zoxide
  fzf-tmux-url   Fuzzy URL extraction and opening
  better-mouse   Predictable high-resolution scrolling across modern TUIs
  tmux-logging   Persistent pane logging and retroactive history capture
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
      {
        plugin = better-mouse-mode;
        extraConfig = ''
          set -g @scroll-down-exit-copy-mode 'off'
          set -g @scroll-without-changing-pane 'on'
          set -g @scroll-in-moused-over-pane 'on'
          set -g @scroll-speed-num-lines-per-scroll '2'
          set -g @emulate-scroll-for-no-mouse-alternate-buffer 'on'
        '';
      }
      {
        plugin = cpu;
        extraConfig = ''
          set -g @cpu_percentage_format '%3.0f%%'
          set -g @ram_percentage_format '%3.0f%%'
          set -g @cpu_low_fg_color '#00ff88'
          set -g @cpu_medium_fg_color '#ffb000'
          set -g @cpu_high_fg_color '#ff3355'
          set -g @ram_low_fg_color '#00ffff'
          set -g @ram_medium_fg_color '#ffb000'
          set -g @ram_high_fg_color '#ff3355'
        '';
      }
      {
        plugin = prefix-highlight;
        extraConfig = ''
          set -g @prefix_highlight_show_copy_mode 'on'
          set -g @prefix_highlight_show_sync_mode 'on'
          set -g @prefix_highlight_prefix_prompt 'CMD'
          set -g @prefix_highlight_copy_prompt 'COPY'
          set -g @prefix_highlight_sync_prompt 'SYNC'
          set -g @prefix_highlight_fg '#07090f'
          set -g @prefix_highlight_bg '#ff00ff'
          set -g @prefix_highlight_copy_mode_attr 'fg=#07090f,bg=#ffb000,bold'
          set -g @prefix_highlight_sync_mode_attr 'fg=#07090f,bg=#ff3355,bold'
          set -g @prefix_highlight_output_prefix ' '
          set -g @prefix_highlight_output_suffix ' '
        '';
      }
      {
        plugin = extrakto;
        extraConfig = ''
          set -g @extrakto_key 'tab'
          set -g @extrakto_grab_area 'window 5000'
          set -g @extrakto_filter_order 'path url word line all'
          set -g @extrakto_clip_mode 'bg'
          set -g @extrakto_clip_tool 'wl-copy'
          set -g @extrakto_fzf_layout 'reverse'
          set -g @extrakto_popup_size '92%,86%'
        '';
      }
      {
        plugin = tmux-thumbs;
        extraConfig = ''
          set -g @thumbs-key 'T'
          set -g @thumbs-reverse 'enabled'
          set -g @thumbs-unique 'enabled'
          set -g @thumbs-position 'right'
          set -g @thumbs-contrast '1'
          set -g @thumbs-osc52 '1'
          set -g @thumbs-fg-color '#00ff88'
          set -g @thumbs-hint-fg-color '#ff00ff'
          set -g @thumbs-select-fg-color '#00ffff'
        '';
      }
      fzf-tmux-url
      tmux-fzf
      {
        plugin = tmux-sessionx;
        extraConfig = ''
          set -g @sessionx-bind 'o'
          set -g @sessionx-prefix 'on'
          set -g @sessionx-window-mode 'on'
          set -g @sessionx-zoxide-mode 'on'
          set -g @sessionx-fzf-builtin-tmux 'on'
          set -g @sessionx-git-branch 'on'
          set -g @sessionx-custom-paths '/etc/nixos,/home/main'
          set -g @sessionx-custom-paths-subdirectories 'false'
          set -g @sessionx-additional-options '--layout=reverse --border=sharp --color=pointer:#ff00ff,marker:#00ff88,spinner:#00ffff'
        '';
      }
      {
        plugin = logging;
        extraConfig = ''
          set -g @logging-path "$HOME/.local/state/tmux/logs"
        '';
      }
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
      set -s copy-command 'wl-copy'

      # Long-lived cockpit semantics and reliable GUI/SSH environment refresh.
      set -g default-shell "${pkgs.zsh}/bin/zsh"
      set -g default-command "${pkgs.zsh}/bin/zsh -l"
      set -g exit-empty off
      set -g destroy-unattached off
      set -g allow-rename off
      setw -g automatic-rename off
      set -g set-titles on
      set -g set-titles-string 'HB · #S:#I:#W · #{pane_current_command}'
      set -g update-environment 'DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS SSH_AUTH_SOCK SSH_AGENT_PID'

      # Renumber windows when one is closed.
      set -g renumber-windows on
      set -g detach-on-destroy off
      set -g display-time 1500
      set -g repeat-time 400
      set -g status-keys vi
      set -g visual-activity off
      set -g visual-bell off
      set -g visual-silence on
      set -g popup-border-style "fg=#00ffff"
      set -g popup-border-lines rounded
      set -g menu-border-style "fg=#ff00ff"
      set -g menu-border-lines rounded
      bind -N "Send literal Ctrl-a" C-a send-prefix

      # Splits keep the current path.
      bind -N "Split right in current path" | split-window -h -c "#{pane_current_path}"
      bind -N "Split down in current path" - split-window -v -c "#{pane_current_path}"
      bind -N "New window in current path" c new-window -c "#{pane_current_path}"
      bind '"' split-window -v -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"

      # Pane movement and resizing stay under the prefix, Vim-style.
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 3
      bind -r K resize-pane -U 3
      bind -r L resize-pane -R 5

      # Operator popups.
      bind -N "Persistent Pi coding agent" p switch-client -t hb:pi
      bind -N "Pi agent popup in current project" C-p display-popup -d "#{pane_current_path}" -w 95% -h 90% -E 'pi --agent hacker-box --name popup'
      bind -N "Persistent live documentation" i switch-client -t hb:docs
      bind -N "Git control with lazygit" g display-popup -d "#{pane_current_path}" -w 90% -h 85% -E lazygit
      bind -N "Process monitor with btop" b display-popup -w 90% -h 85% -E btop
      bind -N "Docker control with lazydocker" D display-popup -d "#{pane_current_path}" -w 95% -h 90% -E lazydocker
      bind -N "systemd unit control" S display-popup -w 95% -h 90% -E systemctl-tui
      bind -N "Health, alerts and log centre" I display-popup -w 97% -h 92% -E hb-control-center
      bind -N "Unified terminal command palette" Space display-popup -d "#{pane_current_path}" -w 98% -h 94% -E hb-term
      bind -N "Cockpit keymap and documentation" ? display-popup -w 90% -h 86% -E 'hb-docs report tmux | less -R'
      bind -N "Disposable login shell" Enter display-popup -d "#{pane_current_path}" -w 92% -h 82% -E 'zsh -l'
      bind -N "Toggle synchronized pane input" y setw synchronize-panes \; display 'pane sync: #{?pane_synchronized,on,off}'

      # Mouse-friendly contextual deck; all entries map to the same canonical
      # commands exposed by the keyboard-first cockpit.
      bind -N "Contextual command deck" m display-menu \
        -T "#[align=centre,fg=#00ffff,bold] HB COMMAND DECK " -x C -y C \
        "Terminal OS" Space 'display-popup -d "#{pane_current_path}" -w 98% -h 94% -E hb-term' \
        "Control centre" I 'display-popup -w 97% -h 92% -E hb-control-center' \
        "Documentation" i 'switch-client -t hb:docs' \
        "Pi coding agent" p 'switch-client -t hb:pi' \
        "Session / project manager" o 'choose-tree -Zw' \
        "" \
        "New window" c 'new-window -c "#{pane_current_path}"' \
        "Split right" '|' 'split-window -h -c "#{pane_current_path}"' \
        "Split down" '-' 'split-window -v -c "#{pane_current_path}"' \
        "" \
        "Reload configuration" r 'source-file ~/.config/tmux/tmux.conf \; display "reloaded"' \
        "Detach client" q 'detach-client'

      # The control window is an appliance: its TUI may be restarted, but its
      # only pane/window cannot be killed accidentally with the default keys.
      bind x if-shell -F '#{==:#{@hb-appliance},1}' \
        'display-message "cockpit appliance pane is persistent"' \
        'confirm-before -p "kill pane #P? (y/n)" kill-pane'
      bind & if-shell -F '#{==:#{@hb-appliance},1}' \
        'display-message "cockpit appliance window is persistent"' \
        'confirm-before -p "kill window #W? (y/n)" kill-window'

      # Reload config on the fly.
      bind -N "Reload tmux configuration" r source-file ~/.config/tmux/tmux.conf \; display "reloaded"

      # Copy-mode: v to start, y to yank to clipboard.
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi y send -X copy-pipe-and-cancel "wl-copy"

      # Status bar — terminal operations telemetry, not decoration.
      set -g status-position bottom
      set -g status-interval 5
      set -g status-justify centre
      set -g status-style "bg=default fg=#768096"
      set -g status-left  "#[bg=#00ffff,fg=#07090f,bold] #S #[bg=default,fg=#768096]│ #[fg=#ff00ff,bold]#(cat /var/lib/hb-mode/current 2>/dev/null || echo dev) #[fg=#768096]│ #[fg=#d7e2ff]#W "
      set -g status-right "#{prefix_highlight}#[fg=#00ffff]CPU #{cpu_percentage} #[fg=#ff00ff]RAM #{ram_percentage} #[fg=#768096]│ #(hb-tmux-status) #[fg=#768096]│ #[fg=#ffb000]%H:%M #[fg=#768096]│ #[fg=#00ff88]#H "
      set -g status-left-length 90
      set -g status-right-length 150
      setw -g window-status-format "#[fg=#768096] #I:#W "
      setw -g window-status-current-format "#[bg=#00ffff,fg=#07090f,bold] #I:#W #[default]"
      setw -g window-status-activity-style "fg=#ffb000,bold"
      set -g pane-border-style "fg=#1e2a3a"
      set -g pane-active-border-style "fg=#00ffff"
      setw -g pane-border-status top
      setw -g pane-border-format "#{?pane_pipe,#[fg=#ff3355,bold] REC ,}#[fg=#768096] #P #[fg=#00ffff]#{pane_current_command} #[fg=#768096]· #{b:pane_current_path} "
      set -g message-style "bg=#1e2a3a fg=#00ffff bold"

      # Toggle mouse, open yazi / fzf session picker.
      bind -N "Toggle mouse support" M set -g mouse \; display "mouse: #{?mouse,on,off}"
      bind -N "File manager with yazi" e display-popup -d "#{pane_current_path}" -w 90% -h 85% -E yazi
      bind -N "Quick session picker" f display-popup -d "#{pane_current_path}" -w 60% -h 40% -E \
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
      bind -N "Claude Code popup" C display-popup -d "#{pane_current_path}" -w 95% -h 90% -E 'claude'
      bind -N "Codex popup" O display-popup -d "#{pane_current_path}" -w 95% -h 90% -E 'codex'

      # HB mode picker — fzf over `hb-mode list` and apply the choice.
      bind X display-popup -w 60% -h 40% -E \
        'm=$(hb-mode list | fzf --prompt="hb-mode › " --with-nth=1 --delimiter="\t" | awk "{print \$1}") && [ -n "$m" ] && hb-mode "$m"'

      # 2026 smart-shell popups.
      # prefix+a → aichat scratch (local Ollama by default).
      # prefix+n → permanent NixOS workspace; changes go through hb-term confirmations.
      # prefix+h → helix quick edit rooted in the current pane path.
      # prefix+t → mprocs task runner (uses mprocs.yaml if present).
      # prefix+A → posting HTTP TUI (P is reserved for pane logging).
      bind -N "AIChat popup" a display-popup -d "#{pane_current_path}" -w 90% -h 85% -E 'aichat'
      bind -N "Permanent NixOS workspace" n switch-client -t hb:nixos
      bind -N "Helix popup" h display-popup -d "#{pane_current_path}" -w 95% -h 90% -E 'hx .'
      bind -N "Project process runner" t display-popup -d "#{pane_current_path}" -w 95% -h 90% -E 'mprocs'
      bind -N "Posting HTTP client" A display-popup -d "#{pane_current_path}" -w 95% -h 90% -E 'posting'

      # Session restore.
      set -g @resurrect-capture-pane-contents 'on'
      set -g @resurrect-strategy-nvim 'session'
    '';
  };

  home.file.".local/state/tmux/logs/.keep".text = "";
}
