---
description: Audit the Nix config for quality, security, and modernity issues
argument-hint: "[optional module path or 'all']"
allowed-tools: Read, Bash(rg:*), Bash(fd:*), Bash(nix eval:*), Bash(git log:*)
---

Perform a targeted audit of the NixOS flake at `/etc/nixos`.

Scope: $ARGUMENTS (default: all modules under ./modules)

Deliver a structured report with:

1. **Security** — check for:
   - Secrets in the Nix store (`config = { adminPassword = "..."; }`)
   - Services binding to `0.0.0.0` that don't need to
   - Deprecated crypto (SSLv3, TLS 1.0/1.1, MD5, SHA-1)
   - Missing `openFirewall = false` on internal-only services
   - Kernel params or sysctl weakening the baseline in hardening.nix

2. **Statix / deadnix drift** — anything the linters would flag that hasn't
   been picked up yet (grouped-key repeats, dead lets, IFD).

3. **Home Manager 25.11 drift** — any use of deprecated options
   (see `feedback_hm_25_11_renames.md` memory file).

4. **Module hygiene** — modules missing the top `/* ... */` doc block,
   modules whose imports are stale, modules that import from paths that no
   longer exist.

5. **Package footprint** — packages installed but not referenced anywhere
   (candidate for removal), and packages referenced in aliases but not
   installed (broken user-facing commands).

Output format:

- Group findings by priority: P0 (fix now) / P1 (fix soon) / P2 (nice).
- For each finding: file path + line, one-line explanation, suggested fix
  as a code snippet.
- End with a one-paragraph verdict.
