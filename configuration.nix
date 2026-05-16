{ config, lib, pkgs, ... }:

{
  imports = [ 
    ./hardware-configuration.nix 
    ./rgb.nix      # <-- IMPORTI I TUOI NUOVI MODULI QUI
    ./audio.nix
  ];

  # --- BOOTLOADER ---
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      useOSProber = true;
      configurationLimit = 10;
    };
  };

  # --- FILE SYSTEMS ---
  fileSystems."/mnt/archive" = {
    device = "/dev/disk/by-label/archive";
    fsType = "ext4";
    options = [ "nofail" ]; 
  };

  # --- NETWORKING & LOCALE ---
  networking.hostName = "nixos-hacker-box";
  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Rome";
  i18n.defaultLocale = "en_US.UTF-8";

  # --- DISPLAY MANAGER (Ly gestisce l'avvio, Hyprland lo lasciamo a Home Manager) ---
  services.displayManager.ly.enable = true;
  services.displayManager.ly.settings = {
    animation = "matrix";
    save = true;
  };
  # Richiesto da Home Manager per far funzionare correttamente i portali XDG (schermate, popup, ecc.)
  environment.pathsToLink = [ "/share/applications" "/share/xdg-desktop-portal" ];

  # --- USER CONFIGURATION ---
  users.groups.i2c = {}; 
  users.users.main = {
    isNormalUser = true;
    description = "Main User";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "i2c" "input" ]; 
    shell = pkgs.zsh;
  };

  # --- SYSTEM PACKAGES ---
  environment.systemPackages = with pkgs; [
    easyeffects pavucontrol helvum
    kitty neovim git wget curl firefox fastfetch starship htop
    wofi cliphist wl-clipboard swww libnotify ddcutil waybar hyprlock hypridle
    python3 gnumake gcc binutils tree-sitter tree wl-gammarelay-rs iputils
    openrgb usbutils i2c-tools swayosd
  ];

  # --- SHELL & PROGRAMS ---
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ll = "ls -l";
      update = "sudo nixos-rebuild switch --flake /etc/nixos/#nixos-hacker-box";
      conf = "sudo -E nvim /etc/nixos/configuration.nix";
      v = "nvim";
      red-alert = "openrgb --mode static --color FF0000";
      rgb-off = "openrgb --mode static --color 000000";
    };
    promptInit = "eval \"$(starship init zsh)\"";
  };

  # --- FONTS ---
  fonts.packages = with pkgs; [
    noto-fonts noto-fonts-color-emoji font-awesome nerd-fonts.jetbrains-mono
  ];

  # --- SECURITY & FLAKES ---
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.11"; 
}
