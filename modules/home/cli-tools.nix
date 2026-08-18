/*
  home/cli-tools.nix — Modern replacements for classic CLI tools.

  Each program below is enabled via its Home Manager module so that shell
  integration (aliases, completions, keybindings) is wired automatically
  in both zsh and bash.

  Programs
  --------
  starship  Cross-shell prompt with language / git status segments.
  eza       Colourful `ls` replacement with tree view and git integration.
  bat       `cat` with syntax highlighting and paging.
  fzf       Interactive fuzzy finder (Ctrl-R history, Ctrl-T files, Alt-C cd).
  zoxide    `cd` replacement that ranks directories by frecency (`z <query>`).
  ripgrep   `grep` on steroids — respects .gitignore, multi-threaded.
  fd        `find` replacement — faster and with sane defaults.
  btop      Modern top/htop replacement with mouse support.
  atuin     Encrypted shared shell history with fuzzy search UI.
  yazi      TUI file manager with preview panes.
*/
{ pkgs, ... }:
{
  programs = {
    starship = {
      enable = true;
      settings = {
        add_newline = false;
        command_timeout = 1000;
        format = "$directory$git_branch$git_status$nix_shell$cmd_duration$line_break$character";
        character = {
          success_symbol = "[❯](bold green)";
          error_symbol = "[❯](bold red)";
        };
        directory = {
          truncation_length = 3;
          truncate_to_repo = true;
        };
        nix_shell = {
          symbol = "❄ ";
          format = "[$symbol$state]($style) ";
        };
      };
    };

    eza = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
      git = true;
      icons = "auto";
      extraOptions = [
        "--group-directories-first"
        "--header"
      ];
    };

    bat = {
      enable = true;
      config = {
        theme = "Dracula";
        style = "numbers,changes,header";
      };
      extraPackages = with pkgs.bat-extras; [
        batman
        batgrep
        batdiff
        prettybat
      ];
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
      defaultCommand = "fd --type f --hidden --exclude .git";
      defaultOptions = [
        "--height=40%"
        "--layout=reverse"
        "--border"
        "--inline-info"
      ];
      fileWidgetCommand = "fd --type f --hidden --exclude .git";
      changeDirWidgetCommand = "fd --type d --hidden --exclude .git";
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
    };

    ripgrep = {
      enable = true;
      arguments = [
        "--smart-case"
        "--hidden"
        "--glob=!.git/"
        "--max-columns=200"
      ];
    };

    btop = {
      enable = true;
      settings = {
        color_theme = "TTY";
        theme_background = false;
        vim_keys = true;
      };
    };

    atuin = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
      settings = {
        auto_sync = false;
        update_check = false;
        style = "compact";
        inline_height = 20;
        search_mode = "fuzzy";
        filter_mode = "global";
      };
    };

    yazi = {
      enable = true;
      enableZshIntegration = true;
    };
  };

  # Standalone CLI utilities not covered by dedicated HM modules.
  home.packages = with pkgs; [
    fd
    ncdu
    duf
    dust
    procs
    sd
    choose
    tldr
    glow
    yq-go
    unzip
    zip
    p7zip
    rsync
  ];
}
