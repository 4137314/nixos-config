/*
  system/boot.nix — Boot loader, kernel, initrd, and /tmp policy.

  Kernel
  ------
  linuxPackages_zen — Zen-tuned kernel. Better desktop scheduling latency
  than the LTS default, with the same nixpkgs rollback safety net. Falls
  back to any prior generation from the GRUB menu on failure.

  Kernel parameters
  -----------------
  amd_pstate=guided  Modern AMD P-state driver. Firmware picks the exact
                     frequency but honours the kernel governor
                     (schedutil, set in modules/system/performance.nix).
                     Near-`performance` throughput at powersave power draw.
  quiet loglevel=3   Silent, cleaner boot. Journal still captures everything;
                     add `debug` at boot time via GRUB `e` if diagnosing.

  GRUB (EFI)
  ----------
  os-prober detects other OS entries (Windows, other Linux). configurationLimit
  caps the NixOS generations shown in the menu without losing rollback ability.
  timeout = 2 — quick auto-boot; press any key to hold the menu.

  Modern initrd
  -------------
  `boot.initrd.systemd.enable = true` uses the systemd-based initrd — parallel
  unit start, cleaner logs, and unlocks features like Plymouth / TPM policies.

  /tmp lifecycle
  --------------
  /tmp is on tmpfs (see modules/system/performance.nix). `cleanOnBoot` is
  redundant with tmpfs but kept as documentation and as a safety net if
  tmpfs ever gets disabled.

  SSD trim
  --------
  `services.fstrim` runs weekly on all SSD/NVMe mountpoints — required for
  sustained write performance on the Btrfs NAS subvolumes and the system NVMe.
*/
{ pkgs, ... }:
{
  boot = {
    # Zen-tuned kernel for desktop responsiveness.
    kernelPackages = pkgs.linuxPackages_zen;

    # AMD P-state (Ryzen) + silent boot.
    # audio.nix and rgb.nix append their own kernelParams; Nix merges lists.
    kernelParams = [
      "amd_pstate=guided"
      "quiet"
      "loglevel=3"
      "udev.log_level=3"
      "rd.udev.log_level=3"
    ];

    # Match kernel loglevel on the console during boot.
    consoleLogLevel = 3;

    loader = {
      timeout = 2;
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

    # tmpfs handles /tmp cleanup at each boot (see performance.nix).
    tmp.cleanOnBoot = true;
  };

  # Weekly TRIM for SSD/NVMe (safe on both system disk and NAS).
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };
}
