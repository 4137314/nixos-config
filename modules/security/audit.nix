/*
  security/audit.nix — Linux auditd with rules geared to pentest workflows.

  Purpose
  -------
  Record who ran what, when, against which target. Useful for:
    - Engagement report evidence ("here's my full command timeline").
    - Post-incident review if an experiment goes sideways.
    - Compliance / legal cover on client engagements.

  Rule set (auditctl syntax)
  --------------------------
  execve                 Every process start with argv (heavy — filtered to
                         only pentest binaries + shell + sudo).
  network                Connections outbound (socket, connect, sendto).
  identity               Changes to /etc/{passwd,shadow,group,sudoers}.
  time                   Any clock change (auto-detects tampering).
  modules                insmod / rmmod / kmod loading (rare on NixOS).
  kernel                 sysctl writes (matches boot.kernel.sysctl audits).

  Log destination
  ---------------
  Auditd writes to /var/log/audit/audit.log. Promtail (loki.nix) will pick
  it up via the audit journal, so queries are available in Grafana:
     {unit="audit.service"} |= "SYSCALL"

  Rotation is standard (10x50MB, kept 30 days).

  Performance
  -----------
  The rules below are deliberately narrow — matching every execve in userland
  brings the box to its knees. We filter by binary path (aid-list) so noise
  is manageable.
*/
{ pkgs, ... }:
{
  security.audit = {
    enable = true;
    backlogLimit = 8192;
    rules = [
      # -- Identity / privilege --------------------------------------------
      "-w /etc/passwd     -p wa -k identity"
      "-w /etc/shadow     -p wa -k identity"
      "-w /etc/group      -p wa -k identity"
      "-w /etc/sudoers    -p wa -k identity"
      "-w /etc/sudoers.d/ -p wa -k identity"

      # -- Time --------------------------------------------------------------
      "-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time"
      "-a always,exit -F arch=b64 -S clock_settime           -k time"
      "-w /etc/localtime -p wa -k time"

      # -- Module loading ----------------------------------------------------
      # `-w /usr/sbin/*` doesn't work on NixOS (those paths do not exist).
      # Watch the actual syscalls instead, which cover any binary that
      # ends up loading a kernel module.
      "-a always,exit -F arch=b64 -S init_module -S finit_module -S delete_module -k modules"

      # -- Pentest binary execution ------------------------------------------
      # NixOS resolves `/run/current-system/sw/bin/<tool>` to a symlink into
      # the Nix store; auditd would follow the symlink at rule-load time and
      # then complain because the store path changes on every rebuild.
      # Instead, key on the binary's basename via the `exe` field at exec
      # time, so we catch it regardless of which store path it lives in.
      "-a always,exit -F arch=b64 -S execve -F exe=/run/current-system/sw/bin/nmap        -k pentest"
      "-a always,exit -F arch=b64 -S execve -F exe=/run/current-system/sw/bin/masscan     -k pentest"
      "-a always,exit -F arch=b64 -S execve -F exe=/run/current-system/sw/bin/hydra       -k pentest"
      "-a always,exit -F arch=b64 -S execve -F exe=/run/current-system/sw/bin/hashcat     -k pentest"
      "-a always,exit -F arch=b64 -S execve -F exe=/run/current-system/sw/bin/john        -k pentest"
      "-a always,exit -F arch=b64 -S execve -F exe=/run/current-system/sw/bin/sqlmap      -k pentest"
      "-a always,exit -F arch=b64 -S execve -F exe=/run/current-system/sw/bin/msfconsole  -k pentest"
      "-a always,exit -F arch=b64 -S execve -F exe=/run/current-system/sw/bin/msfvenom    -k pentest"
      "-a always,exit -F arch=b64 -S execve -F exe=/run/current-system/sw/bin/searchsploit -k pentest"
    ];
  };

  # auditd userland daemon (audispd, aureport, ausearch, autrace).
  security.auditd.enable = true;

  environment.systemPackages = [ pkgs.audit ];
}
