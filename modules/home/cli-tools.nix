/*
  home/cli-tools.nix — Modern replacements for classic CLI tools.

  Each program below is enabled via its Home Manager module so that shell
  integration (aliases, completions, keybindings) is wired automatically
  in both zsh and bash.

  Programs
  --------
  starship         Cross-shell prompt with language / git status segments.
  eza              Colourful `ls` replacement with tree view and git integration.
  bat              `cat` with syntax highlighting and paging.
  fzf              Interactive fuzzy finder (Ctrl-R history, Ctrl-T files, Alt-C cd).
  zoxide           `cd` replacement that ranks directories by frecency (`z <query>`).
  ripgrep          `grep` on steroids — respects .gitignore, multi-threaded.
  fd               `find` replacement — faster and with sane defaults.
  btop             Modern top/htop replacement with mouse support.
  atuin            Encrypted shared shell history with fuzzy search UI.
  yazi             TUI file manager with preview panes.
  broot            Interactive tree navigator (`br`).
  helix            Modal editor with built-in LSP + tree-sitter.
  jujutsu          Modern DVCS on top of git (`jj`).
  aichat           Local-first LLM CLI (Alt+E in the shell replaces buffer
                   with a proposed command — see modules/workstation/shell.nix).
  navi             Interactive cheatsheet (`Ctrl+G` in the shell).
  carapace         Universal completion engine bridging bash/zsh/fish.
  nix-your-shell   Wraps `nix shell/develop/run` to reuse zsh + prompt.
  ddgr/w3m         Terminal-native web lookup and readable page dumps for Pi.
  jc/fx            Convert command output to JSON and inspect JSON interactively.
  comma            Run a command from nixpkgs without installing it permanently.
  nom/nvd          Readable Nix build logs and generation diffs.
  pay-respects     Fast command correction (`f` after a failed command).
  fzf-git          Fuzzy Git files (`Alt-G`) and branches (`Alt-Shift-G`).

  Zsh integration
  ---------------
  This host's zsh is configured at the system level (modules/workstation/
  shell.nix), so Home Manager's `enableZshIntegration` cannot attach. The
  system rc sources the integration scripts explicitly for tools that need
  it (fzf, atuin, yazi, carapace, nix-your-shell, navi and aichat).
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
      enableZshIntegration = false;
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
      enableZshIntegration = false;
      enableBashIntegration = true;
      defaultCommand = "fd --type f --hidden --exclude .git";
      defaultOptions = [
        "--height=45%"
        "--layout=reverse"
        "--border=sharp"
        "--info=inline-right"
        "--prompt=λ "
      ];
      fileWidgetCommand = "fd --type f --hidden --exclude .git";
      changeDirWidgetCommand = "fd --type d --hidden --exclude .git";
    };

    zoxide = {
      enable = true;
      enableZshIntegration = false;
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
      enableZshIntegration = false;
      enableBashIntegration = true;
      settings = {
        auto_sync = false;
        update_check = false;
        style = "compact";
        inline_height = 20;
        search_mode = "fuzzy";
        filter_mode = "global";
        history_filter = [
          "^export .*(_KEY|_TOKEN|_SECRET|_PASSWORD)="
          "^piauth($| )"
          "^sops($| )"
        ];
      };
    };

    yazi = {
      enable = true;
      enableZshIntegration = false;
    };

    # ---------------------------------------------------------------
    # 2026 cutting-edge additions. Enabled here; shell integration
    # for the ones HM cannot attach (system zsh) is done manually in
    # modules/workstation/shell.nix.
    # ---------------------------------------------------------------

    broot = {
      enable = true;
      enableZshIntegration = false;
    };

    helix = {
      enable = true;
      defaultEditor = false; # keep neovim as $EDITOR
      settings = {
        theme = "catppuccin_mocha";
        editor = {
          line-number = "relative";
          cursorline = true;
          mouse = true;
          bufferline = "multiple";
          color-modes = true;
          auto-save = true;
          idle-timeout = 250;
          completion-trigger-len = 2;
          indent-guides.render = true;
          lsp.display-messages = true;
          statusline.center = [ "file-modification-indicator" ];
        };
      };
    };

    jujutsu = {
      enable = true;
      settings = {
        ui.default-command = "log";
        ui.diff.format = "git";
        # user.{name,email} come from git config automatically.
      };
    };

    aichat = {
      enable = true;
      settings = {
        model = "ollama:qwen2.5-coder:14b";
        temperature = 0.3;
        top_p = 0.9;
        save = true;
        save_session = null;
        highlight = true;
        editor = "nvim";
        keybindings = "emacs";
        wrap = "auto";
        stream = true;
        theme = "dracula";

        # Local-first: Ollama for zero-cost inference. Cloud providers
        # (openai, claude) can be layered by exporting OPENAI_API_KEY /
        # ANTHROPIC_API_KEY — aichat picks them up from env automatically.
        clients = [
          {
            type = "openai-compatible";
            name = "ollama";
            api_base = "http://127.0.0.1:11434/v1";
            api_key = "ollama-local-not-a-secret";
            models = [
              {
                name = "qwen2.5:7b";
                max_input_tokens = 32768;
              }
              {
                name = "qwen2.5-coder:7b";
                max_input_tokens = 32768;
              }
              {
                name = "qwen2.5-coder:14b";
                max_input_tokens = 16384;
              }
              {
                name = "deepseek-r1:8b";
                max_input_tokens = 16384;
              }
              {
                name = "llama3.2:3b";
                max_input_tokens = 8192;
              }
            ];
          }
        ];
      };
    };

    navi = {
      enable = true;
      enableZshIntegration = false;
    };

    carapace = {
      enable = true;
      enableZshIntegration = false;
    };

    nix-your-shell = {
      enable = true;
      enableZshIntegration = false;
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
    tealdeer
    glow
    yq-go
    ddgr
    w3m
    lynx
    htmlq
    jc
    fx
    gum
    hyperfine
    watchexec
    entr

    # Nix ergonomics and reproducible package discovery.
    nix-output-monitor
    nvd
    nix-init
    nix-update

    # Search, refactoring, inspection, and repeatable project tasks.
    ast-grep
    tokei
    scc
    grex
    hexyl
    ouch
    just
    pay-respects

    # System, network, logs, and container TUIs.
    bottom
    dua
    bandwhich
    doggo
    gping
    trippy
    lnav
    systemctl-tui
    lazydocker
    chafa
    presenterm
    unzip
    zip
    p7zip
    rsync
  ];

  # Searchable with Ctrl-G through the navi widget loaded by system Zsh.
  xdg.configFile."navi/cheats/hacker-box.cheat".text = ''
    % hacker-box, nixos, terminal

    # Validate evaluation, lint, dead code, and the complete system build
    make check

    # Preview activation without changing the running system
    make dry

    # Validate first, then activate the new generation
    make switch

    # Compare the two newest NixOS generations
    ndiff

    # Run a nixpkgs command without installing it permanently
    , <command> <args>

    # Search code and open the selected match in $EDITOR
    rgi <pattern>

    # Select a Git project below a directory and enter it
    cproj <directory>

    # Ask the local Ollama coding model for a shell command
    aiq <request>

    # Correct the previous command in place
    f

    # Inspect failed services in a TUI
    systemctl-tui

    # Follow system logs interactively
    journalctl -f -o short-iso | lnav
  '';
}
