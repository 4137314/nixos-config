{ pkgs, ... }:

# ─────────────────────────────────────────────────────────────────────────────
# Configurazione sistema principale.
# I dettagli sono delegati ai moduli sotto modules/.
# ─────────────────────────────────────────────────────────────────────────────
{
  imports = [
    ./hardware-configuration.nix
    ./modules/hardware/audio.nix
    ./modules/hardware/rgb.nix
    ./modules/workstation/display.nix
    ./modules/workstation/shell.nix
    ./modules/workstation/packages.nix
    ./modules/nas/samba.nix
    ./modules/nas/syncthing.nix
  ];

  # ── Bootloader ─────────────────────────────────────────────────────────────
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint     = "/boot";
    };
    grub = {
      enable             = true;
      device             = "nodev";
      efiSupport         = true;
      useOSProber        = true;
      configurationLimit = 10;
    };
  };

  # ── Storage ────────────────────────────────────────────────────────────────
  # Disco secondario (etichetta "archive"). nofail = non blocca il boot se assente.
  fileSystems."/mnt/archive" = {
    device  = "/dev/disk/by-label/archive";
    fsType  = "ext4";
    options = [ "nofail" ];
  };

  # ── Rete & Locale ──────────────────────────────────────────────────────────
  networking.hostName              = "nixos-hacker-box";
  networking.networkmanager.enable = true;
  time.timeZone                    = "Europe/Rome";
  i18n.defaultLocale               = "en_US.UTF-8";

  # ── Utenti ────────────────────────────────────────────────────────────────
  users.groups.i2c = {};
  users.users.main = {
    isNormalUser = true;
    description  = "Main User";
    extraGroups  = [ "wheel" "networkmanager" "video" "audio" "i2c" "input" "docker" ];
    shell        = pkgs.zsh;
  };

  # ── Nix ───────────────────────────────────────────────────────────────────
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree         = true;
  system.stateVersion                 = "25.11";
}
