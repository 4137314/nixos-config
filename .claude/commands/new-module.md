---
description: Scaffold a new NixOS module following repo conventions
argument-hint: "<category>/<name>  (e.g. security/audit  or  home/kitty)"
allowed-tools: Write, Read, Bash(fd:*)
---

Scaffold a new module at `modules/$ARGUMENTS.nix`.

Follow every convention documented in `/etc/nixos/CLAUDE.md`:

- Top-of-file `/* ... */` doc block in English with sections:
  Purpose / Scope, Architecture, Configuration, First-run, Trade-offs.
- Module signature `_:` if no args used, else `{ pkgs, ... }:` listing
  ONLY what is used.
- Group repeated top-level keys under one attrset (`services = { X=...; Y=...; }`).
- No secrets in the Nix store — reference `config.sops.secrets.<name>.path`.
- If it opens firewall ports, comment which client uses each.

After writing the module:

1. Add its import to `configuration.nix` (or `modules/home/default.nix`
   if it's a Home Manager module).
2. Run `make check` and report the result.
3. If check fails, iterate on the module until it passes — do not leave
   the tree in a broken state.
