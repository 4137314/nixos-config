/*
  system/performance.nix — Cross-cutting performance and efficiency tuning.

  This module aggregates tunings that don't have a natural home elsewhere:
  sysctl bumps for dev workloads, systemd shutdown timeouts, journald
  quirks, /tmp on tmpfs, and CPU governor.

  What lives elsewhere
  --------------------
    modules/system/nix.nix         Nix daemon niceness + disk-full auto-GC
    modules/system/boot.nix        Kernel package + kernelParams + GRUB timeout
    modules/hardware/gpu-amd.nix   AMD-specific graphics stack
    modules/system/networking.nix  Baseline network sysctls (BBR, fq, …)
    modules/system/hardening.nix   Security-oriented sysctls

  Nix daemon TMPDIR
  -----------------
  /tmp is on tmpfs (RAM). Big Nix builds (chromium, webkit, kernels) can
  spike to 20 GB+ of temporary space and blow out a tmpfs. We redirect
  the nix-daemon's TMPDIR to /var/tmp so those builds land on the NVMe
  and never risk an OOM on the tmpfs. Everything else (shell scratch,
  `mktemp`, extract, ephemeral CLI files) still benefits from tmpfs speed.
*/
_: {
  # --------------------------------------------------------------------------
  # CPU governor — schedutil cooperates with AMD P-state (see boot.nix
  # kernelParams: amd_pstate=guided). Best balance of responsiveness and
  # idle power draw on modern Ryzen chips.
  # --------------------------------------------------------------------------
  powerManagement.cpuFreqGovernor = "schedutil";

  # --------------------------------------------------------------------------
  # /tmp on tmpfs.
  # --------------------------------------------------------------------------
  boot.tmp = {
    useTmpfs = true;
    tmpfsSize = "50%"; # capped by kernel; matches typical desktop default
  };

  # Redirect nix builds off /tmp (see module docstring).
  systemd.services.nix-daemon.environment.TMPDIR = "/var/tmp";

  # --------------------------------------------------------------------------
  # Systemd shutdown timeouts — go from ~90 s worst case to 10 s.
  # System manager uses the modern `systemd.settings.Manager` API (25.11+);
  # the user manager option was not yet migrated in this release, so it
  # still takes free-form `extraConfig`.
  # --------------------------------------------------------------------------
  systemd = {
    settings.Manager = {
      DefaultTimeoutStopSec = "10s";
      DefaultTimeoutAbortSec = "10s";
    };
    user.extraConfig = ''
      DefaultTimeoutStopSec=10s
      DefaultTimeoutAbortSec=10s
    '';
  };

  # --------------------------------------------------------------------------
  # Journald — drop wall/tty broadcast overhead (verbose services spam it).
  # Other journald options live in modules/system/journald.nix.
  # --------------------------------------------------------------------------
  services.journald.extraConfig = ''
    ForwardToWall=no
  '';

  # --------------------------------------------------------------------------
  # Sysctl — dev / network / VM efficiency bumps.
  # Additive: BBR + fq are in networking.nix, hardening in hardening.nix.
  # --------------------------------------------------------------------------
  boot.kernel.sysctl = {
    # File-watching. Modern editors and dev tools (neovim, tsc, cargo,
    # direnv, watchman, tailwindcss --watch) exhaust the 8192 default fast.
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 512;

    # More address-space regions — Steam, Wine, some databases hit this.
    "vm.max_map_count" = 1048576;

    # TCP fast open (client + server). Cuts one RTT on repeat connections.
    "net.ipv4.tcp_fastopen" = 3;

    # Keep TCP fast after long idles (browsers, ssh, remote APIs).
    "net.ipv4.tcp_slow_start_after_idle" = 0;

    # Larger socket buffers — helps NAS + Immich + big scp/rsync transfers.
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.ipv4.tcp_rmem" = "4096 87380 16777216";
    "net.ipv4.tcp_wmem" = "4096 65536 16777216";

    # Bound outbound queue to reduce bufferbloat (paired with fq qdisc).
    "net.ipv4.tcp_notsent_lowat" = 16384;
  };
}
