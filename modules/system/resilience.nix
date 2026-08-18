/*
  system/resilience.nix — Reliability, thermal, and OOM management.

  Purpose
  -------
  Prevent the workstation from freezing under memory pressure (heavy pentest
  workloads: burpsuite + jellyfin + msfconsole + browser is easily 20 GB+)
  and keep the CPU on the latest microcode errata.

  CPU microcode
  -------------
  The AMD path applies for this box (Ryzen). NixOS silently ignores the
  Intel path on non-Intel hardware, so enabling both is a no-op fallback
  in case the box is ever migrated.

  earlyoom
  --------
  Userland OOM daemon that acts BEFORE the kernel OOM killer. Sends SIGTERM
  at 5% free RAM, SIGKILL at 2%. Prefers to kill the largest RSS process
  (typically a runaway browser tab or a stuck fuzzer) instead of a random
  system daemon.

  ZRAM
  ----
  Compressed swap in RAM (zstd). 25% of RAM becomes ~50-75% effective swap
  at negligible CPU cost. Removes the need for a swap partition on NVMe.

  Firmware updates
  ----------------
  fwupd exposes `fwupdmgr update` for BIOS, SSD firmware, dock updates, etc.
  Runs entirely in userland — no BIOS floppy required.
*/
{ pkgs, ... }:
{
  # --------------------------------------------------------------------------
  # CPU microcode errata (Spectre, Retbleed, INCEPTION, …).
  # --------------------------------------------------------------------------
  hardware.cpu = {
    amd.updateMicrocode = true;
    intel.updateMicrocode = true;
  };

  # --------------------------------------------------------------------------
  # Firmware updates via fwupd (BIOS, SSD, peripherals).
  # --------------------------------------------------------------------------
  services.fwupd.enable = true;

  # --------------------------------------------------------------------------
  # Compressed RAM swap — replaces a disk swap partition.
  # --------------------------------------------------------------------------
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
    priority = 100;
  };

  # --------------------------------------------------------------------------
  # earlyoom — kill greedy processes before the kernel OOM freezes the box.
  # --------------------------------------------------------------------------
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
    extraArgs = [
      "-g" # kill the whole process group
      "--avoid"
      "'^(Xorg|sshd|systemd|hyprland|zsh)$'"
      "--prefer"
      "'^(chrome|firefox|electron|node|python|java|ruby)$'"
    ];
  };

  # Explicit dependency so nix-collect-garbage does not GC the killer.
  environment.systemPackages = [ pkgs.earlyoom ];
}
