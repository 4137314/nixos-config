/*
  system/boot.nix — Boot loader, modern initrd, and /tmp policy.

  GRUB (EFI)
  ----------
  os-prober detects other OS entries (Windows, other Linux). configurationLimit
  caps the NixOS generations shown in the menu without losing rollback ability.

  Modern initrd
  -------------
  `boot.initrd.systemd.enable = true` uses the systemd-based initrd — parallel
  unit start, cleaner logs, and unlocks features like Plymouth / TPM policies.

  /tmp lifecycle
  --------------
  `boot.tmp.cleanOnBoot = true` empties /tmp on each reboot so leftover
  pentest artefacts (packet captures, decoded payloads) do not accumulate.

  SSD trim
  --------
  `services.fstrim` runs weekly on all SSD/NVMe mountpoints — required for
  sustained write performance on the Btrfs NAS subvolumes and the system NVMe.
*/
_: {
  boot = {
    loader = {
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

    # Modern systemd-based initrd — faster boot, better logs.
    initrd.systemd.enable = true;

    # Wipe /tmp at every reboot.
    tmp.cleanOnBoot = true;
  };

  # Weekly TRIM for SSD/NVMe (safe on both system disk and NAS).
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };
}
