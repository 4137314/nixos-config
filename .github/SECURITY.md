# Security policy

This is a personal NixOS flake for a single-operator home lab. It intentionally
exposes services on a LAN and on a private Tailscale mesh. Please read below
before opening a security issue.

## Scope

**In scope**

- Secrets accidentally committed in plaintext to this repository.
- Hard-coded credentials in Nix expressions.
- Config paths that route production traffic through unvetted third-party
  binary caches.
- Firewall rules that expose LAN-only services to the public internet.
- Broken hardening (sysctl regressions, missing `PermitRootLogin no`, etc.).

**Out of scope**

- Vulnerabilities in upstream packages — report those to their maintainers.
- Weaknesses in services this box hosts for local use (Nextcloud, Jellyfin,
  etc.) — these are covered by the upstream projects' security teams.
- Findings that require physical access to the box.

## Reporting

Open a **private security advisory** on this repository (Security tab →
Report a vulnerability). Do NOT open a public issue for anything sensitive.

Include:

- The vulnerable file path and commit SHA.
- A minimal reproduction (config snippet + observed behaviour).
- The impact you can demonstrate.

I aim to acknowledge within 3 days and to patch within 14 days for anything
above `low`. Public disclosure follows the fix by at least 30 days unless we
agree otherwise.

## Handling secrets in this repo

- All secrets go through `sops-nix` (see [modules/system/secrets.nix](../modules/system/secrets.nix)).
- The plaintext `secrets/*.yaml` should never appear in git — the pattern is
  in `.gitignore`. Encrypted `secrets/*.yaml.enc` is fine.
- Anything that must be in `/etc/` before sops-nix is bootstrapped is
  documented in [CLAUDE.md](../CLAUDE.md) under "First-time / post-refactor
  manual steps" — never commit those files.

If you find a plaintext secret in the git history, treat it as compromised
and rotate it before opening the advisory.
