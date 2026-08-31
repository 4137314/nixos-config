/*
  home/packages.nix — User-space packages managed by Home Manager.

  The `unstable` argument is the nixpkgs-unstable package set instantiated in
  flake.nix and forwarded via extraSpecialArgs. Use it for packages where the
  stable channel lags significantly behind upstream.

  Package groups
  --------------
  Neovim runtime  ripgrep, fd, tree-sitter, pynvim — consumed by plugins.
  Node / Python   nodejs_22, python311 — required by LSP servers and tools.
  Dev tools       lazygit (TUI), jq (JSON processing).
  AI tooling      claude-code — CLI for Claude, NixOS-patched build.
  Nix tooling     nixd / nil (LSP), deadnix (dead-code finder), statix (linter).
*/
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Neovim runtime dependencies
    ripgrep
    fd
    tree-sitter
    nodejs_22
    python311
    python311Packages.pynvim

    # Developer utilities
    lazygit
    jq

    # AI coding CLIs — user-space installs. See:
    #   modules/home/claude-code.nix  declarative ~/.claude/ config
    #   modules/home/pi-agent.nix     Pi (multi-model TUI) + Ollama routing
    claude-code
    codex

    # Nix language tooling
    nixd
    nil
    deadnix
    statix

    # Nix ecosystem TUIs.
    #   nh          modern nixos-rebuild wrapper (`nh os switch`)
    #   nix-inspect browse the option tree of the live system
    #   nix-tree    dependency-tree visualiser for a derivation
    #   nix-diff    compare two derivations
    #   nix-du      see what's eating space in /nix/store
    nh
    nix-inspect
    nix-tree
    nix-diff
    nix-du

    # Modern developer TUIs.
    #   posting     HTTP client TUI (Postman replacement)
    #   mprocs      run multiple processes side-by-side in a TUI
    #   xh          Rust rewrite of httpie
    #   dive        inspect Docker image layers
    #   ntfy-sh     CLI for the local ntfy push server (see NTFY_TOPIC hook)
    posting
    mprocs
    xh
    dive
    ntfy-sh
  ];
}
