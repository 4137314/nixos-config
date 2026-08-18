---
description: Show status of restic + btrbk + snapper backups
allowed-tools: Bash(systemctl:*), Bash(journalctl:*), Bash(sudo restic:*), Bash(sudo btrfs:*), Bash(sudo snapper:*), Bash(df -h:*)
---

Report the current state of all backup subsystems.

For each subsystem, show:

1. **snapper** (Btrfs local snapshots — modules/nas/storage.nix)
   - `sudo snapper -c media list --disable-used-space | tail -10`
   - Latest snapshot age, count, disk used.

2. **btrbk** (Btrfs replication to /mnt/backup — modules/backup/btrbk.nix)
   - `systemctl status btrbk.timer btrbk.service --no-pager`
   - Last successful send (grep `journalctl -u btrbk -n 50`).
   - `df -h /mnt/backup` if mounted; warn if not mounted.

3. **restic** (offsite B2 — modules/backup/restic.nix)
   - `systemctl status restic-backups-offsite.timer --no-pager`
   - Latest snapshot: `sudo restic-offsite-repo snapshots --last 1` (if
     environment file exists).
   - Repository health from last check.

Deliver a table:
| Layer | Last success | Age | Storage used | Status |
|--------|--------------|-----|--------------|--------|

Flag anything >24h stale as WARNING and >7d as CRITICAL.
