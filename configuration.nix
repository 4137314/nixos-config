{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # --- BOOTLOADER (GRUB Setup) ---
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      useOSProber = true; # Rileva altri OS come Windows
      configurationLimit = 10; # Evita di intasare il boot con 1000 vecchie versioni
    };
  };

  # --- NETWORKING & LOCALE ---
  networking.hostName = "nixos-hacker-box";
  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Rome"; # Impostato per Trento/Italia
  i18n.defaultLocale = "it_IT.UTF-8";

  # --- SOUND (Pipewire: il top per Wayland) ---
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # --- DISPLAY MANAGER & WINDOW MANAGER ---
  programs.hyprland.enable = true;
  
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  # Fix per far apparire tuigreet correttamente
  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal"; # Logga gli errori se non parte
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };

  # --- USER CONFIGURATION ---
  users.users.main = {
    isNormalUser = true;
    description = "Main User";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    shell = pkgs.zsh;
  };


  # --- SYSTEM PACKAGES ---
  environment.systemPackages = with pkgs; [
    # Core
    kitty neovim git wget curl
    # Wayland Tools
    wofi waybar cliphist wl-clipboard swww libnotify
    # Utilities
    firefox dolphin fastfetch starship htop
    # Mercenario Tools (Inizio arsenale)
    python3 gnumake gcc binutils
    tree-sitter
    tree
  ];

  # --- SHELL & PROGRAMS ---
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ll = "ls -l";
      update = "sudo nixos-rebuild switch";
      conf = "sudoedit /etc/nixos/configuration.nix"; # Uso sudoedit come suggerito!
      v = "nvim";
    };
    promptInit = "eval \"$(starship init zsh)\"";
  };

  # --- FONTS ---
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-emoji
    font-awesome
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
  ];

  # --- SECURITY & EXTRA ---
  nix.settings.experimental-features = [ "nix-command" "flakes" ]; # Ti servirà per il futuro
  nixpkgs.config.allowUnfree = true; # Necessario per driver e software proprietario

  system.stateVersion = "23.11"; 
}
