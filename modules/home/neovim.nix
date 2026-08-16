/*
  home/neovim.nix — Neovim editor, declaratively managed via Home Manager.

  Package
  -------
  Sourced from nixpkgs-unstable to stay close to the latest upstream release.
  The binary is exposed as the default $EDITOR and $VISUAL.

  Plugin management
  -----------------
  Plugins are managed by lazy.nvim, which downloads them from the internet at
  first launch. This is intentional: it allows pinning plugins independently
  from the Nix package set (via lazy-lock.json, which lives in ~/.config/nvim/
  as a regular writable file — not managed by Nix).

  Configuration files
  -------------------
  The Lua config tree (init.lua, lua/**) lives in modules/home/nvim/ and is
  symlinked into ~/.config/nvim/ via xdg.configFile. Each file becomes a
  read-only Nix store symlink; the parent directory remains a real mutable
  directory so lazy.nvim can write its lock file and plugin cache.

  First-time setup
  ----------------
  Before the first `make switch`, remove (or rename) the existing config:

    mv ~/.config/nvim ~/.config/nvim.bak

  Then after switching, open Neovim and run:

    :Lazy sync

  extraPackages
  -------------
  Tools added to Neovim's runtime PATH (not the system PATH):
    lua-language-server  LSP for editing the Lua config files.
    stylua               Lua code formatter.
    ripgrep / fd         Required by Telescope for live grep and file finding.
*/
{ pkgs, unstable, ... }:
{
  programs.neovim = {
    enable        = true;
    package       = unstable.neovim-unwrapped;
    defaultEditor = true;

    extraPackages = with pkgs; [
      lua-language-server
      stylua
      ripgrep
      fd
    ];
  };

  xdg.configFile = {
    "nvim/init.lua".source                         = ./nvim/init.lua;
    "nvim/lua/core/options.lua".source             = ./nvim/lua/core/options.lua;
    "nvim/lua/core/keymaps.lua".source             = ./nvim/lua/core/keymaps.lua;
    "nvim/lua/core/autocmds.lua".source            = ./nvim/lua/core/autocmds.lua;
    "nvim/lua/plugins.lua".source                  = ./nvim/lua/plugins.lua;
    "nvim/lua/plugins/tools/telescope.lua".source  = ./nvim/lua/plugins/tools/telescope.lua;
    "nvim/lua/plugins/tools/treesitter.lua".source = ./nvim/lua/plugins/tools/treesitter.lua;
    "nvim/lua/plugins/ui/toogle.lua".source        = ./nvim/lua/plugins/ui/toogle.lua;
    "nvim/lua/plugins/ui/tree.lua".source          = ./nvim/lua/plugins/ui/tree.lua;
  };
}
