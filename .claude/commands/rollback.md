---
description: List NixOS generations and prepare a rollback plan
allowed-tools: Bash(sudo nix-env --list-generations:*), Bash(nixos-rebuild list-generations)
---

Help me roll back the NixOS system.

Steps:

1. List the last 10 system generations:
   `sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -10`
2. Highlight the CURRENT generation (marked with `(current)`).
3. Ask which target generation the user wants to roll back to.
4. Produce the exact command they should run, e.g.:
   `sudo nixos-rebuild switch --rollback` (previous generation)
   `sudo /nix/var/nix/profiles/system-<N>-link/bin/switch-to-configuration switch`
   (specific generation number N)
5. Warn if the target is older than 7 days — stateful services (Nextcloud,
   Postgres) may have on-disk schema changes that don't roll back cleanly.

Never execute the rollback yourself — this is destructive-adjacent, the
operator must run it.
