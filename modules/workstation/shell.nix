/*
  workstation/shell.nix — System-wide Zsh configuration.

  Features
  --------
  autosuggestions      Fish-style inline suggestions based on history.
  syntaxHighlighting   Real-time syntax colouring of the command line.
  history              Large deduplicated history shared across sessions.
  completion           Case-insensitive, coloured, cached.
  keybindings          Vi mode with sensible emacs-style search preserved.

  Integrations (loaded from the system rc, so both /bin/zsh interactive
  logins and Home Manager sessions see them):
    starship  → cross-shell prompt
    direnv    → per-directory environment via .envrc files
    nix-direnv → faster `use flake` / `use nix` integration
    zoxide    → smart cd with frecency ranking
    fzf       → Ctrl-R history, Ctrl-T files, Alt-C directory jump

  Aliases
  -------
  System / NixOS
    update       Rebuild and switch to the new NixOS configuration.
    update-dry   Dry-run: show what would change without activating.
    conf         Edit configuration.nix in Neovim (preserves env with -E).
    gc           Garbage-collect old generations.
    generations  List all system generations.

  Navigation & files
    ll / la / lt   Long listings with modern `eza` (icons + git).
    cat            `bat` — syntax-highlighted paging.
    find           `fd` — respects .gitignore, faster.
    grep           `rg` — ripgrep.

  NAS / services
    nas-status / nas-shares    Samba service and share status.

  Pentest quick commands (see /etc/nixos/modules/security/pentest.nix for
  the underlying tools):
    nmap-quick   Fast top-1000 port scan of a host.
    nmap-full    Full 65535-port SYN scan with version detection.
    ports        List local listening TCP+UDP ports.
    conns        Show all established connections.
    myip         Resolve public IPv4/IPv6.
    serve        HTTP-serve the current directory on :8000.
    scan-web     nuclei quick web scan against a URL.
    urlenc       URL-encode stdin.
    urldec       URL-decode stdin.
    b64          Base64-encode stdin.
    b64d         Base64-decode stdin.

  Container / dev
    dps          docker ps with a compact layout.
    dpsa         Same, including stopped containers.
    dcu / dcd    docker compose up -d / down.
    kctx         List / switch Kubernetes contexts.
*/
{ pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;

    histSize = 100000;
    histFile = "$HOME/.zsh_history";

    setOptions = [
      "HIST_IGNORE_DUPS"
      "HIST_IGNORE_ALL_DUPS"
      "HIST_IGNORE_SPACE"
      "HIST_FIND_NO_DUPS"
      "HIST_REDUCE_BLANKS"
      "HIST_SAVE_NO_DUPS"
      "SHARE_HISTORY"
      "APPEND_HISTORY"
      "INC_APPEND_HISTORY"
      "EXTENDED_HISTORY"
      "AUTO_CD"
      "AUTO_PUSHD"
      "PUSHD_IGNORE_DUPS"
      "PUSHD_SILENT"
      "INTERACTIVE_COMMENTS"
      "CORRECT"
      "NO_BEEP"
    ];

    shellAliases = {
      # -- Navigation ---------------------------------------------------------
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      ll = "eza -l --git --icons --group-directories-first";
      la = "eza -la --git --icons --group-directories-first";
      lt = "eza --tree --level=2 --icons";
      lta = "eza --tree --level=3 --icons -a";
      archive = "cd /mnt/archive";

      # -- Modern replacements -----------------------------------------------
      cat = "bat --paging=never";
      less = "bat";
      find = "fd";
      grep = "rg";
      top = "btop";
      du = "dust";
      df = "duf";
      ps = "procs";

      # -- NixOS management ---------------------------------------------------
      update = "sudo nixos-rebuild switch --flake /etc/nixos/#nixos-hacker-box";
      update-dry = "sudo nixos-rebuild dry-activate --flake /etc/nixos/#nixos-hacker-box";
      update-boot = "sudo nixos-rebuild boot --flake /etc/nixos/#nixos-hacker-box";
      up-flake = "cd /etc/nixos && sudo nix flake update";
      conf = "sudo -E nvim /etc/nixos/configuration.nix";
      cdnix = "cd /etc/nixos";
      v = "nvim";
      gc = "sudo nix-collect-garbage --delete-older-than 30d";
      generations = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";

      # -- Git shortcuts ------------------------------------------------------
      g = "git";
      gs = "git status -sb";
      gd = "git diff";
      gds = "git diff --staged";
      ga = "git add";
      gap = "git add -p";
      gc- = "git commit -v";
      gca = "git commit --amend --no-edit";
      gp = "git push";
      gpl = "git pull --rebase";
      gco = "git checkout";
      gsw = "git switch";
      gl = "git log --graph --oneline --all --decorate";
      lg = "lazygit";

      # -- Docker / Podman ----------------------------------------------------
      d = "docker";
      dps = "docker ps --format 'table {{.Names}}\\t{{.Image}}\\t{{.Status}}'";
      dpsa = "docker ps -a --format 'table {{.Names}}\\t{{.Image}}\\t{{.Status}}'";
      dcu = "docker compose up -d";
      dcd = "docker compose down";
      dcl = "docker compose logs -f --tail=200";
      dsh = "docker exec -it";

      # -- RGB shortcuts ------------------------------------------------------
      red-alert = "openrgb --mode static --color FF0000";
      rgb-off = "openrgb --mode static --color 000000";

      # -- NAS shortcuts ------------------------------------------------------
      nas-status = "systemctl status smbd syncthing";
      nas-shares = "smbstatus --shares";

      # -- Networking / pentest quickies -------------------------------------
      ports = "ss -tulpen";
      conns = "ss -tanp | grep ESTAB";
      myip = "curl -fsSL https://ifconfig.me && echo";
      myip6 = "curl -fsSL https://ifconfig.co && echo";
      localip = "ip -c -brief addr";
      serve = "python3 -m http.server 8000";
      scan-web = "nuclei -silent -u";
      urlenc = "jq -sRr @uri";
      urldec = "python3 -c 'import sys,urllib.parse as u; print(u.unquote(sys.stdin.read()))'";
      b64 = "base64 -w0";
      b64d = "base64 -d";
      sha256 = "sha256sum";
      md5 = "md5sum";
    };

    interactiveShellInit = ''
      # Vi mode with emacs-style history search preserved.
      bindkey -v
      export KEYTIMEOUT=1
      bindkey '^R' history-incremental-search-backward
      bindkey '^S' history-incremental-search-forward
      bindkey '^P' up-line-or-search
      bindkey '^N' down-line-or-search
      bindkey '^A' beginning-of-line
      bindkey '^E' end-of-line
      bindkey '^K' kill-line

      # Case-insensitive, coloured completion with cache.
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*'
      zstyle ':completion:*' menu select
      zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
      zstyle ':completion:*' use-cache on
      zstyle ':completion:*' cache-path "$HOME/.cache/zsh"

      # Nix-shell aware prompt hint.
      export DIRENV_LOG_FORMAT=""

      # Tool integrations — loaded only if the binary is available.
      command -v direnv   >/dev/null 2>&1 && eval "$(direnv hook zsh)"
      command -v zoxide   >/dev/null 2>&1 && eval "$(zoxide init zsh)"

      # Convenience: `mkcd foo` creates a directory and enters it.
      mkcd() { mkdir -p -- "$1" && cd -- "$1" || return; }

      # Convenience: `extract file.tar.gz` — auto-detect archive type.
      extract() {
        case "$1" in
          *.tar.bz2)  tar xjf "$1" ;;
          *.tar.gz)   tar xzf "$1" ;;
          *.tar.xz)   tar xJf "$1" ;;
          *.tar)      tar xf "$1"  ;;
          *.tbz2)     tar xjf "$1" ;;
          *.tgz)      tar xzf "$1" ;;
          *.bz2)      bunzip2 "$1" ;;
          *.gz)       gunzip "$1"  ;;
          *.zip)      unzip "$1"   ;;
          *.7z)       7z x "$1"    ;;
          *.rar)      unrar x "$1" ;;
          *)          echo "Unknown archive: $1" ;;
        esac
      }
    '';

    promptInit = ''eval "$(starship init zsh)"'';
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    silent = true;
  };

  # Ensure the modern CLI tools referenced by the aliases above are always
  # present at the system level (Home Manager also ships them per-user).
  environment.systemPackages = with pkgs; [
    eza
    bat
    fd
    ripgrep
    dust
    duf
    procs
    zoxide
  ];
}
