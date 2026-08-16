{ pkgs, inputs, ... }:

# ─────────────────────────────────────────────────────────────────────────────
# Pacchetti Home Manager per l'utente "main".
# unstable: canale separato per pacchetti più aggiornati (es. Neovim).
# ─────────────────────────────────────────────────────────────────────────────
let
  # legacyPackages NON eredita allowUnfree dal sistema: va impostato qui.
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in
{
  home.packages = [
    # ── Editor ───────────────────────────────────────────────────────────────
    unstable.neovim-unwrapped   # versione più recente dal canale unstable
    pkgs.ripgrep                # ricerca veloce (usata da Neovim/Telescope)
    pkgs.fd                     # find moderno
    pkgs.tree-sitter            # parser incrementale

    # ── Runtime ──────────────────────────────────────────────────────────────
    pkgs.nodejs_22
    pkgs.python311
    pkgs.python311Packages.pynvim

    # ── Dev tools ────────────────────────────────────────────────────────────
    pkgs.lazygit                # TUI per git
    pkgs.jq                     # processore JSON da CLI

    # ── Nix tooling ──────────────────────────────────────────────────────────
    pkgs.claude-code            # CLI Claude patchata per NixOS
    pkgs.nixd                   # LSP per i file .nix
    pkgs.nil                    # LSP alternativo
    pkgs.deadnix                # rileva codice Nix morto
    pkgs.statix                 # linter per Nix
  ];
}
