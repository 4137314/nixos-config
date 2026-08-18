# Contributing

Personal home-lab flake. External contributions are welcome for:

- Bug reports on modules that generalise beyond this host.
- Suggestions for hardening / observability defaults.
- Compatibility fixes when nixpkgs / Home Manager APIs drift.

## Local workflow

```bash
nix develop          # gets nixfmt, statix, deadnix, nixd, sops, age

make check           # eval + statix + deadnix (must be green before PR)
make fmt             # nixfmt-rfc-style, in-place
make dry             # dry-activate against the live system (optional)
```

Every PR runs the same `check` + `lint` + `fmt` matrix in CI via
[.github/workflows/check.yml](workflows/check.yml).

## Module conventions

See [CLAUDE.md](../CLAUDE.md) for the full list. Short version:

1. Module signature is `_:` when the body uses no args; `{ pkgs, ... }:`
   otherwise. Never destructure arguments you don't use — deadnix will fail.
2. Group repeated top-level keys under one attrset — no bare
   `services.X = …; services.Y = …;` pairs (statix W20).
3. Start every module with a `/* … */` English doc block: purpose,
   configuration highlights, trade-offs, first-run steps.
4. Never put secrets in the Nix store. Use `passwordFile` / `environmentFile`
   / `config.sops.secrets.<name>.path`.
5. Every `networking.firewall.allowedTCPPorts` entry needs a one-line
   comment explaining which client uses the port.

## Commit messages

Conventional Commits — `type(scope): summary`.

Common types:

- `feat:` new capability
- `fix:` bug fix
- `refactor:` no behaviour change
- `docs:` docs / comments only
- `chore:` deps, tooling, CI
- `sec:` security-relevant change

Scope is optional but useful: `feat(hub): add miniflux rss module`.

## Pull request checklist

- [ ] `make check` passes.
- [ ] `make fmt` produced no diff.
- [ ] New module has the top `/* … */` doc block.
- [ ] Any new firewall opening is annotated.
- [ ] Any new secret goes through sops-nix or a `*File =` option.
- [ ] Screenshots / GIFs attached if the PR changes the desktop UI.
