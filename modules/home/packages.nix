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

    # AI & Claude integration
    claude-code

    # Nix language tooling
    nixd
    nil
    deadnix
    statix
  ];
}
