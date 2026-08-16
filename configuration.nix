/*
  configuration.nix — System-level NixOS configuration.

  This file is intentionally thin: it handles identity (hostname, users,
  storage, boot) and delegates everything else to the modules under modules/.

  Module tree
  -----------
  modules/hardware/   Hardware drivers and peripheral control.
  modules/workstation Desktop environment, shell, and system packages.
  modules/nas/        Network-attached storage services.
*/
{ pkgs, ... }:
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

  # ---------------------------------------------------------------------------
  # Boot
  # ---------------------------------------------------------------------------

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
      # Keep at most 10 generations in the GRUB menu.
      configurationLimit = 10;
    };
  };

  # ---------------------------------------------------------------------------
  # Storage
  # ---------------------------------------------------------------------------

  # Secondary disk labelled "archive".
  # nofail prevents the boot sequence from blocking when the disk is absent.
  fileSystems."/mnt/archive" = {
    device  = "/dev/disk/by-label/archive";
    fsType  = "ext4";
    options = [ "nofail" ];
  };

  # ---------------------------------------------------------------------------
  # Networking & locale
  # ---------------------------------------------------------------------------

  networking = {
    hostName            = "nixos-hacker-box";
    networkmanager.enable = true;
  };

  time.timeZone      = "Europe/Rome";
  i18n.defaultLocale = "en_US.UTF-8";

  # ---------------------------------------------------------------------------
  # Users
  # ---------------------------------------------------------------------------

  users.groups.i2c = { };

  users.users.main = {
    isNormalUser = true;
    description  = "Main User";
    extraGroups  = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "i2c"
      "input"
      "docker"
    ];
    shell = pkgs.zsh;
  };

  # ---------------------------------------------------------------------------
  # Nix
  # ---------------------------------------------------------------------------

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;
  system.stateVersion        = "25.11";
}
