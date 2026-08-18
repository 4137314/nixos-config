/*
  system/hardening.nix — Kernel and namespace hardening.

  Trade-offs
  ----------
  This is a hacker-box, not an appliance. We keep restrictions that catch
  routine bad actors but avoid measures that break local debugging (ptrace
  restrictions, JIT lockdown, module loading blocks).

  Applied
  -------
  dmesg_restrict          Hide kernel log from non-root.
  kptr_restrict           Hide kernel pointers in /proc.
  unprivileged_bpf        Disabled — closes a large recent CVE surface.
  bpf_jit_harden          Harden BPF JIT against side-channel attacks.
  protected_hardlinks     Prevent hardlink-based TOCTOU exploits.
  protected_symlinks      Prevent symlink-based TOCTOU exploits.

  Deliberately NOT applied
  ------------------------
  kernel.yama.ptrace_scope > 0
    Would break gdb attach for local exploit development. Keep at 0.

  kernel.modules_disabled
    Would prevent loading Wireshark helper modules, aircrack-ng airmon-ng,
    etc. Keep unset.

  security.lockdown
    Would break kernel debugging and BPF tooling. Keep off.
*/
_: {
  boot.kernel.sysctl = {
    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restrict" = 2;
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
  };

  # rtkit is enabled by audio.nix; polkit is needed for user-space device
  # control (e.g. NetworkManager). Both stay on.
  security = {
    protectKernelImage = true;
    unprivilegedUsernsClone = true; # keep true — Podman rootless needs it
    apparmor.enable = false; # NixOS default; enabling requires per-profile work
  };
}
