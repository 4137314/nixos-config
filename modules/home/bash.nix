/*
  home/bash.nix — Bash configuration for scripts and fallback shell.

  Rationale
  ---------
  The default interactive shell is zsh (workstation/shell.nix). Bash is
  still needed as:
    - The interpreter for shebang-less scripts and CI hooks.
    - A fallback when zsh cannot start (rescue shells, chroots).
    - The shell used by many pentest wrappers (proxychains, msfconsole).

  History behaviour
  -----------------
  A large deduplicated history is shared across sessions immediately —
  matches the zsh setup so muscle memory transfers between shells.

  Aliases mirror the zsh set (workstation/shell.nix) so basic productivity
  works identically on both shells.
*/
_: {
  programs.bash = {
    enable = true;

    historyControl = [
      "ignoredups"
      "ignorespace"
    ];
    historySize = 100000;
    historyFileSize = 200000;

    shellOptions = [
      "histappend"
      "checkwinsize"
      "extglob"
      "globstar"
      "checkjobs"
      "autocd"
      "cdspell"
      "dirspell"
    ];

    shellAliases = {
      ll = "ls -lh --color=auto";
      la = "ls -lha --color=auto";
      ".." = "cd ..";
      "..." = "cd ../..";
      grep = "grep --color=auto";
      diff = "diff --color=auto";
      ip = "ip -c";
      v = "nvim";
      hub = "hb-term";
      control = "hb-control-center";
      pideck = "hb-pi";
      piresume = "pi -c";
      pimodels = "pi --list-models";
      piagents = "pi --agent hacker-box --name hacker-box";
      piup = "pi update --all";
      pidev = "pi --agent dev-scout --name dev-scout";
    };

    bashrcExtra = ''
      # Share history across sessions in real time.
      PROMPT_COMMAND="history -a; history -n; $PROMPT_COMMAND"

      # direnv is system-managed. Starship, zoxide, fzf and atuin are injected
      # by their Home Manager modules, avoiding duplicate hooks.
      command -v direnv   >/dev/null 2>&1 && eval "$(direnv hook bash)"
      command -v pay-respects >/dev/null 2>&1 && eval "$(pay-respects bash --alias f --nocnf)"

      y() {
        local cwd_file cwd
        cwd_file=$(mktemp -t yazi-cwd.XXXXXX) || return
        yazi "$@" --cwd-file="$cwd_file"
        cwd=$(command cat -- "$cwd_file")
        command rm -f -- "$cwd_file"
        if [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
          builtin cd -- "$cwd"
        fi
      }

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
          "picode"       "nix read-only scout (nix-scout agent)" \
          "pidev"        "code implementation (dev-scout agent)" \
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
    '';
  };
}
