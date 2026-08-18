---
description: Diagnose a failing systemd service
argument-hint: "<service-name>"
allowed-tools: Bash(systemctl:*), Bash(journalctl:*), Bash(ss:*), Bash(rg:*), Read
---

Diagnose systemd service: **$ARGUMENTS**

Sequence:

1. `systemctl status $ARGUMENTS --no-pager` — current state, PID, last exit code.
2. `journalctl -u $ARGUMENTS --since '1 hour ago' --no-pager -n 200` — recent
   logs. If the service failed at boot, widen to `--since '1 day ago'`.
3. If the service listens on the network, verify the port:
   `ss -tulpn | rg $ARGUMENTS` — is anything bound?
4. If it's a NixOS module, find its config file:
   `rg -l 'services\\.$ARGUMENTS' /etc/nixos/modules` and read the module.
5. Cross-check dependencies: `systemctl list-dependencies $ARGUMENTS`.

Deliver:

- **Symptom** — one sentence from the logs.
- **Root cause hypothesis** — most likely explanation.
- **Fix** — either a shell command (with warning if privileged/destructive)
  or a config change (file path + diff snippet).
- **Verification** — how to confirm the fix worked.

If the root cause is unclear after the above, list the top 3 suspects with
what evidence would disambiguate.
