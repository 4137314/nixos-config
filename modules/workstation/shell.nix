_:

# ─────────────────────────────────────────────────────────────────────────────
# Shell: Zsh con autocompletamento, syntax highlighting, starship e direnv.
# ─────────────────────────────────────────────────────────────────────────────
{
  programs.zsh = {
    enable                    = true;
    autosuggestions.enable    = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      # Navigazione
      ll      = "ls -l";
      la      = "ls -la";
      archive = "cd /mnt/archive";

      # NixOS
      update     = "sudo nixos-rebuild switch --flake /etc/nixos/#nixos-hacker-box";
      update-dry = "sudo nixos-rebuild dry-activate --flake /etc/nixos/#nixos-hacker-box";
      conf       = "sudo -E nvim /etc/nixos/configuration.nix";
      v          = "nvim";

      # RGB
      red-alert = "openrgb --mode static --color FF0000";
      rgb-off   = "openrgb --mode static --color 000000";

      # NAS
      nas-status = "systemctl status smbd syncthing";
      nas-shares = "smbstatus --shares";
    };

    interactiveShellInit = ''
      eval "$(direnv hook zsh)"
    '';

    promptInit = ''eval "$(starship init zsh)"'';
  };

  # direnv + nix-direnv: ambienti Nix per-progetto automatici (.envrc)
  programs.direnv = {
    enable            = true;
    nix-direnv.enable = true;
  };
}
