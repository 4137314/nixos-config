/*
  system/users.nix — Interactive user accounts and group membership.

  Design
  ------
  `main` is the sole interactive user on this workstation. Extra
  personas are handled by *modes* (see `modules/system/modes.nix`),
  not by extra user accounts — the persona/mode changes running
  services and desktop policy, not `$HOME`.

  Group membership is expressed as a *union of purpose-scoped lists*
  (system + network + graphics + hardware + dev + media + security)
  so it is easy to audit what is granted and why, and easy to add
  a new bucket without touching unrelated ones.

  Where each group is defined
  ---------------------------
    wheel, networkmanager, video, render, audio,
    input, dialout, plugdev, kvm, libvirtd            NixOS built-ins
    docker                                            virtualisation.docker (workstation/packages.nix)
    i2c                                               hardware/default.nix   (OpenRGB SMBus)
    media                                             nas/storage.nix        (shared media library)
    wireshark                                         security/pentest.nix   (unprivileged capture)
    hb-modes                                          system/modes.nix       (hb-mode CLI)

  Adding a new privilege
  ----------------------
  Prefer declaring the group in the module that owns the underlying
  resource, then append the group name to the relevant bucket below.
  Do NOT add ad-hoc `users.groups.foo` here.
*/
{ pkgs, ... }:
let
  systemGroups = [
    "wheel" # sudo / polkit admin
    "hb-modes" # runtime persona switch (system/modes.nix)
  ];

  networkGroups = [
    "networkmanager" # manage LAN / Wi-Fi connections
  ];

  graphicsGroups = [
    "video" # DRM / display access
    "render" # AMD KFD + renderD* (ROCm)
  ];

  hardwareGroups = [
    "audio" # ALSA / PipeWire direct access
    "input" # evdev
    "i2c" # OpenRGB SMBus (hardware/rgb.nix)
    "dialout" # serial / USB TTY (Arduino, UART)
    "plugdev" # USB hardware (Proxmark, HID)
  ];

  devGroups = [
    "docker" # docker daemon socket
    "kvm" # /dev/kvm — virt-manager, qemu
    "libvirtd" # libvirt domain management
  ];

  mediaGroups = [
    "media" # /srv/nas/{media,downloads} (nas/storage.nix)
  ];

  securityGroups = [
    "wireshark" # unprivileged packet capture
  ];
in
{
  users.users.main = {
    isNormalUser = true;
    description = "Main User";
    shell = pkgs.zsh;
    extraGroups =
      systemGroups
      ++ networkGroups
      ++ graphicsGroups
      ++ hardwareGroups
      ++ devGroups
      ++ mediaGroups
      ++ securityGroups;
  };

  # `plugdev` is not a built-in NixOS group; declare it here because no
  # single module "owns" it (it is a POSIX convention across several
  # udev-managed devices).
  users.groups.plugdev = { };
}
