/*
  workstation/shell.nix — System-wide Zsh configuration.

  Features
  --------
  autosuggestions    Fish-style inline suggestions based on history.
  syntaxHighlighting Real-time syntax colouring of the command line.
  starship           Cross-shell prompt with Git, Nix, and language indicators.
  direnv             Per-directory environment activation via .envrc files.
  nix-direnv         Faster `use flake` / `use nix` direnv integration.

  Aliases
  -------
  update      Rebuild and switch to the new NixOS configuration.
  update-dry  Dry-run: show what would change without activating.
  conf        Edit configuration.nix in Neovim (preserves env with -E).
  nas-status  Quick status check for Samba and Syncthing.
  nas-shares  Show active Samba connections.
*/
_:
{
  programs.zsh = {
    enable                    = true;
    autosuggestions.enable    = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      # Navigation
      ll      = "ls -l";
      la      = "ls -la";
      archive = "cd /mnt/archive";

      # NixOS management
      update     = "sudo nixos-rebuild switch --flake /etc/nixos/#nixos-hacker-box";
      update-dry = "sudo nixos-rebuild dry-activate --flake /etc/nixos/#nixos-hacker-box";
      conf       = "sudo -E nvim /etc/nixos/configuration.nix";
      v          = "nvim";

      # RGB shortcuts
      red-alert = "openrgb --mode static --color FF0000";
      rgb-off   = "openrgb --mode static --color 000000";

      # NAS shortcuts
      nas-status = "systemctl status smbd syncthing";
      nas-shares = "smbstatus --shares";
    };

    interactiveShellInit = ''
      eval "$(direnv hook zsh)"
    '';

    promptInit = ''eval "$(starship init zsh)"'';
  };

  programs.direnv = {
    enable            = true;
    nix-direnv.enable = true;
  };
}
