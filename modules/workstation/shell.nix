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
    atuin     → searchable, persistent history on Ctrl-R
    fzf-git   → fuzzy Git files (Alt-G) and branches (Alt-Shift-G)
    comma     → run missing nixpkgs commands without permanent installation
    navi      → searchable project/system cheatsheets on Ctrl-G

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

  Pi agent console
    hb-pi        Pull-up Pi scratchpad panel in Hyprland, tmux elsewhere.
    piq          One-shot Pi answer in print mode.
    pisys        Pi session rooted in /etc/nixos.
*/
{ pkgs, ... }:
let
  # nixpkgs' wrapper replaces the word `fzf` in Zsh widget names as well as
  # command invocations, yielding invalid names such as /nix/store/.../fzf-git-*.
  # Repair only that accidental replacement and extend its smoke test to Zsh.
  fzfGit = pkgs.fzf-git-sh.overrideAttrs (previousAttrs: {
    postPatch = previousAttrs.postPatch + ''
      substituteInPlace fzf-git.sh \
        --replace-fail '${pkgs.fzf}/bin/fzf-git-' 'fzf-git-'
    '';
    installCheckPhase = previousAttrs.installCheckPhase + ''
      HOME=$(mktemp -d) ${pkgs.zsh}/bin/zsh -dfi -c \
        "source $out/share/fzf-git-sh/fzf-git.sh"
    '';
  });
in
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
      update = "cd /etc/nixos && make switch";
      update-dry = "cd /etc/nixos && make dry";
      update-boot = "cd /etc/nixos && make check && sudo nixos-rebuild boot --flake path:/etc/nixos/#nixos-hacker-box";
      up-flake = "cd /etc/nixos && nix flake update";
      conf = "nvim /etc/nixos/configuration.nix";
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
      ddive = "dive";

      # -- nh — modern nixos-rebuild wrapper (added alongside legacy alias) --
      nhs = "cd /etc/nixos && make switch";
      nhd = "cd /etc/nixos && make dry";
      nhc = "nh clean all --keep 5 --keep-since 30d";
      nhr = "nh search";
      nom-build = "nom build";

      # -- AI shortcuts -------------------------------------------------------
      ai = "aichat";
      aiq = "aichat -e"; # -e = execute: propose a shell command

      # -- Modern replacements (cont.) ----------------------------------------
      http = "xh";
      https = "xh --https";
      logs = "journalctl -f -o short-iso | lnav";
      services = "systemctl-tui";
      hub = "hb-term";
      control = "hb-control-center";
      docker-ui = "lazydocker";
      disk = "dua interactive";
      netwatch = "sudo bandwhich";
      dns = "doggo";
      trace = "trip";
      code-stats = "tokei";

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

      # -- Pi / local agent console ------------------------------------------
      pideck = "hb-pi";
      piresume = "pi -c";
      pimodels = "pi --list-models";
      piagents = "pi --agent hacker-box --name hacker-box";
      piup = "pi update --all";
      pidev = "pi --agent dev-scout --name dev-scout";
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

      # =====================================================================
      # 2026 MEGA-shell layer — modern zsh plugins + AI + universal completion.
      # =====================================================================

      # --- Zsh plugins sourced from the Nix store (no user profile needed).
      source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
      source ${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh
      source ${pkgs.zsh-you-should-use}/share/zsh/plugins/you-should-use/you-should-use.plugin.zsh
      source ${pkgs.zsh-autopair}/share/zsh/zsh-autopair/autopair.zsh

      # Home Manager does not own zsh on this host, so load its user tools
      # here explicitly. Atuin intentionally wins Ctrl-R; fzf keeps Ctrl-T
      # and Alt-C. fzf-git adds the Ctrl-G key sequences for Git objects.
      command -v fzf   >/dev/null 2>&1 && source <(fzf --zsh)
      command -v atuin >/dev/null 2>&1 && eval "$(atuin init zsh --disable-up-arrow)"
      source ${fzfGit}/share/fzf-git-sh/fzf-git.sh
      bindkey '^[g' fzf-git-files-widget
      bindkey '^[G' fzf-git-branches-widget

      # fzf-tab: fuzzy tab-completion with previews.
      zstyle ':fzf-tab:complete:cd:*'   fzf-preview 'eza -1 --icons --color=always $realpath 2>/dev/null'
      zstyle ':fzf-tab:complete:z:*'    fzf-preview 'eza -1 --icons --color=always $realpath 2>/dev/null'
      zstyle ':fzf-tab:complete:kill:*' fzf-preview 'ps -p $word -o cmd --no-headers -w -w 2>/dev/null'
      zstyle ':fzf-tab:*'               switch-group '<' '>'
      zstyle ':fzf-tab:*'               fzf-min-height 20

      # history-substring-search: Up/Down navigate matching history.
      bindkey '^[[A' history-substring-search-up
      bindkey '^[[B' history-substring-search-down
      bindkey -M vicmd 'k' history-substring-search-up
      bindkey -M vicmd 'j' history-substring-search-down

      # you-should-use: nag when a defined alias would have shortened a command.
      export YSU_MESSAGE_POSITION="after"
      export YSU_MODE=ALL

      # --- Integrations for HM-declared tools whose zsh-integration is off.
      command -v carapace       >/dev/null 2>&1 && {
        export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
        source <(carapace _carapace zsh)
      }
      command -v nix-your-shell >/dev/null 2>&1 && nix-your-shell zsh | source /dev/stdin
      command -v navi           >/dev/null 2>&1 && source <(navi widget zsh)

      # broot: `br` alias (avoids the launcher script side-effects).
      command -v broot          >/dev/null 2>&1 && alias br='broot'
      command -v pay-respects   >/dev/null 2>&1 && eval "$(pay-respects zsh --alias f --nocnf)"

      # --- Alt+E: send buffer to aichat, replace with the proposed command.
      # Local-first (Ollama). Set OPENAI_API_KEY / ANTHROPIC_API_KEY to add
      # cloud providers; then `aichat --info` shows them.
      _hb_aichat_widget() {
        if [[ -n "$BUFFER" ]] && command -v aichat >/dev/null 2>&1; then
          local _prompt=$BUFFER
          BUFFER+=" ⌛"
          zle -I && zle redisplay
          local _out
          _out=$(aichat -e "$_prompt" 2>/dev/null) || _out="$_prompt"
          BUFFER=$_out
          zle end-of-line
        fi
      }
      zle -N _hb_aichat_widget
      bindkey '\ee' _hb_aichat_widget

      # --- Push a ntfy notification when a command takes >30 s.
      # Opt-in: `export NTFY_TOPIC=system` (or any topic) to enable.
      # Server: local ntfy on http://127.0.0.1:2586 (modules/monitoring/ntfy.nix).
      zmodload zsh/datetime
      autoload -Uz add-zsh-hook
      _hb_cmd_start=0
      _hb_cmd_last=""
      _hb_preexec() { _hb_cmd_start=$EPOCHSECONDS; _hb_cmd_last=$1; }
      _hb_precmd()  {
        if [[ -n $NTFY_TOPIC && $_hb_cmd_start != 0 ]]; then
          local dur=$(( EPOCHSECONDS - _hb_cmd_start ))
          if (( dur > 30 )); then
            curl -sS -H "Title: cmd done ($dur s)" \
              -d "''${_hb_cmd_last[1,80]}" \
              "http://127.0.0.1:2586/''${NTFY_TOPIC}" >/dev/null 2>&1 &!
          fi
        fi
        _hb_cmd_start=0
      }
      add-zsh-hook preexec _hb_preexec
      add-zsh-hook precmd  _hb_precmd

      # Convenience: `mkcd foo` creates a directory and enters it.
      mkcd() { mkdir -p -- "$1" && cd -- "$1" || return; }

      # Yazi wrapper: leaving the TUI changes the parent shell directory.
      y() {
        local cwd_file cwd
        cwd_file=$(mktemp -t yazi-cwd.XXXXXX) || return
        yazi "$@" --cwd-file="$cwd_file"
        cwd=$(command cat -- "$cwd_file")
        command rm -f -- "$cwd_file"
        if [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
          builtin cd -- "$cwd"
        fi
      }

      # Pick a Git project below a root and enter it (`cproj ~/src`).
      cproj() {
        local root selection
        root=''${1:-$HOME}
        selection=$(fd --hidden --type d '^\.git$' --max-depth 6 "$root" 2>/dev/null \
          | sed -E 's#/.git/?$##' \
          | fzf --prompt='project › ' --preview='eza -la --git --icons --color=always {}') || return
        builtin cd -- "$selection" && zoxide add "$selection"
      }

      # Select a file with a syntax-highlighted preview and edit it.
      fedit() {
        local file
        file=$(fd --hidden --type f --exclude .git \
          | fzf --prompt='edit › ' --preview='bat --color=always --style=numbers --line-range=:500 {}') || return
        "''${EDITOR:-nvim}" -- "$file"
      }

      # Ripgrep → fzf → editor at the selected line.
      rgi() {
        if (( $# == 0 )); then
          print -u2 'usage: rgi <ripgrep-pattern>'
          return 2
        fi
        local match file rest line
        match=$(rg --line-number --no-heading --color=never --smart-case -- "$@" \
          | fzf --delimiter=: --prompt='match › ' \
              --preview='bat --color=always --style=numbers --highlight-line {2} {1}') || return
        file=''${match%%:*}
        rest=''${match#*:}
        line=''${rest%%:*}
        "''${EDITOR:-nvim}" "+$line" -- "$file"
      }

      # Compare the two newest NixOS generations with a readable package diff.
      ndiff() {
        local -a generations
        generations=(/nix/var/nix/profiles/system-*-link(N))
        if (( ''${#generations} < 2 )); then
          print -u2 'ndiff: fewer than two NixOS generations found'
          return 1
        fi
        nvd diff "''${generations[-2]}" "''${generations[-1]}"
      }

      nixsize() {
        nix path-info --closure-size --human-readable "$@" | sort -h -k2
      }

      # `notify <cmd>` — force a ntfy push regardless of duration.
      notify() {
        local topic=''${NTFY_TOPIC:-system}
        "$@"
        local rc=$?
        curl -sS -H "Title: cmd done (rc=$rc)" -d "$*" \
          "http://127.0.0.1:2586/$topic" >/dev/null 2>&1 &!
        return $rc
      }

      # Pi helpers. `piq` is non-interactive; the others keep normal TUI flow.
      piq() {
        if [ "$#" -eq 0 ]; then
          pi --agent hacker-box
        else
          pi --agent hacker-box --name quick -p "$*"
        fi
      }

      pisys() {
        (cd /etc/nixos && pi --agent hacker-box --name system "$@")
      }

      piweb() {
        pi --agent web-recon --name web-recon "$@"
      }

      picode() {
        (cd /etc/nixos && pi --agent nix-scout --name nix-scout "$@")
      }

      pidev() {
        pi --agent dev-scout --name dev-scout "$@"
      }

      # Write ~/.pi/agent/auth.json from current env vars (never touches Nix store).
      piauth() {
        local auth="$HOME/.pi/agent/auth.json"
        if [ -z "$ANTHROPIC_API_KEY" ] && [ -z "$OPENAI_API_KEY" ]; then
          printf '\e[31merror:\e[0m export ANTHROPIC_API_KEY and/or OPENAI_API_KEY first\n'
          return 1
        fi
        jq -n \
          --arg ant "$ANTHROPIC_API_KEY" \
          --arg oai "$OPENAI_API_KEY" \
          '. | if $ant != "" then .anthropic = {apiKey: $ant} else . end
             | if $oai != "" then .openai   = {apiKey: $oai} else . end' \
          > "$auth"
        chmod 600 "$auth"
        printf '\e[32mwritten:\e[0m %s\n' "$auth"
      }

      # Cloud model shortcuts — require ANTHROPIC_API_KEY / OPENAI_API_KEY in env.
      picloud() {
        pi --agent hacker-box --model anthropic/claude-sonnet-4-6 --name cloud "$@"
      }

      pismart() {
        pi --agent hacker-box --model anthropic/claude-opus-4-7 --name smart "$@"
      }

      pihaiku() {
        pi --agent hacker-box --model anthropic/claude-haiku-4-5-20251001 --name haiku "$@"
      }

      pigpt() {
        pi --agent hacker-box --model openai/gpt-4o --name gpt "$@"
      }

      pihelp() {
        printf '\e[36m%-14s\e[0m %s\n' \
          "piq [q]"      "quick one-shot (hacker-box, local Ollama)" \
          "pisys"        "system session rooted in /etc/nixos" \
          "piweb"        "web research (web-recon agent)" \
          "picode"       "nix read-only scout (nix-scout)" \
          "pidev"        "code implementation (dev-scout)" \
          "piauth"       "write ~/.pi/agent/auth.json from env vars" \
          "picloud"      "claude-sonnet-4-6  (needs ANTHROPIC_API_KEY)" \
          "pismart"      "claude-opus-4-7    (needs ANTHROPIC_API_KEY)" \
          "pihaiku"      "claude-haiku-4-5   (needs ANTHROPIC_API_KEY)" \
          "pigpt"        "gpt-4o             (needs OPENAI_API_KEY)" \
          "pideck"       "full Pi TUI pull-up" \
          "piresume"     "resume last Pi session" \
          "pimodels"     "list available models" \
          "piup"         "update Pi and packages"
      }

      # Ouch detects formats from extensions and handles archives uniformly.
      extract() {
        ouch decompress -- "$@"
      }

      compress() {
        ouch compress -- "$@"
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
    fzf
    atuin
    yazi
    carapace
    navi
    nix-your-shell
    aichat
    ouch
    pay-respects
    fzfGit
    zsh-autopair
    nix-output-monitor
    nvd
  ];

  environment.sessionVariables = {
    NH_FLAKE = "/etc/nixos";
    NIXPKGS_ALLOW_UNFREE = "1";
    FZF_CTRL_T_OPTS = "--preview 'bat --color=always --style=numbers --line-range=:500 {}'";
    FZF_ALT_C_OPTS = "--preview 'eza --tree --level=2 --icons --color=always {}'";
  };
}
