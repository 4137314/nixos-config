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
    };

    bashrcExtra = ''
      # Share history across sessions in real time.
      PROMPT_COMMAND="history -a; history -n; $PROMPT_COMMAND"

      # direnv and starship — activated only when the binaries are on PATH.
      command -v direnv   >/dev/null 2>&1 && eval "$(direnv hook bash)"
      command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
      command -v zoxide   >/dev/null 2>&1 && eval "$(zoxide init bash)"
      command -v fzf      >/dev/null 2>&1 && eval "$(fzf --bash 2>/dev/null || true)"
    '';
  };
}
