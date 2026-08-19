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

## Branch naming

We follow **GitHub Flow**: `master` is the only long-lived branch.
Every change lives on a short-lived topic branch off `master` and
merges back via PR after CI is green.

Branch prefix mirrors the commit `type`:

```
feat/<slug>       new capability
fix/<slug>        bug fix
refactor/<slug>   no behaviour change
docs/<slug>       docs only
chore/<slug>      deps, tooling, CI
sec/<slug>        security-relevant
```

Slug = kebab-case, ≤ 40 chars, e.g. `feat/observatory-brain` or
`fix/adguard-yaml-http-address`.

Direct pushes to `master` are reserved for trivial one-liners (typo
in a comment, README fix). Anything module-level goes through a PR
so the CI matrix + reviewer eye kicks in.

## Commit messages

Conventional Commits — `type(scope): summary`.
Enforced on PR titles by `.github/workflows/commit-lint.yml`
(via `amannn/action-semantic-pull-request`).

Allowed types:
`feat`, `fix`, `refactor`, `docs`, `chore`, `sec`, `test`,
`perf`, `build`, `ci`, `revert`, `style`.

Subject rules:

- Lowercase first letter.
- Imperative mood ("add", not "added" or "adds").
- No trailing period.
- ≤ 72 chars for the subject line; wrap the body at 72.

Body (optional but strongly encouraged for anything > 3 lines):

- Explain **why**, not what. The diff already shows the what.
- Reference issues with `Refs #N` or `Closes #N`.

Example:

```
fix(vikunja): use service.secret; idempotent env init

`both service.secret and service.jwtsecret are set … Using
service.secret` — upstream deprecated jwtsecret in 25.11.
Rename `VIKUNJA_SERVICE_JWTSECRET` → `VIKUNJA_SERVICE_SECRET`;
init script transparently migrates legacy files.

Closes #42
```

## Labels

The label catalogue is defined declaratively in
[`.github/labels.yml`](labels.yml) and synced to GitHub by
[`.github/workflows/labels-sync.yml`](workflows/labels-sync.yml).
To add / rename / recolour a label: edit the yml, PR, merge — the
sync workflow does the rest.

Three axes to tag every issue / PR:

- **Type** — matches the Conventional Commits prefix (`type:feat`, …).
- **Scope** — matches a `modules/<x>/` directory (`scope:hub`, …).
- **Priority + status** — see the yml file for the palette.

## Project board

Roadmap + backlog live on the
[**nixos-hacker-box Roadmap** Project v2](https://github.com/users/4137314/projects/12).

Custom fields:

- **Priority** — populated from the `priority:*` label
- **Effort** — populated from the `effort:*` label
- **Status** — default Todo / In Progress / Done
- **Milestone** — v1.0-baseline · v1.1-observability · v1.2-self-healing · v2.0-secrets-migration

New issues and PRs are added automatically by
[`.github/workflows/project-add.yml`](workflows/project-add.yml).
Priority / Effort are pulled from labels — apply the right
`priority:pX-*` and `effort:*` labels and the project view sorts
itself.

Views to consult:

- **Kanban** — status swimlanes for daily triage
- **Roadmap** — grouped by milestone, sorted by priority
- **By scope** — grouped by `scope:*` label, useful before touching
  a module tree (see what's in flight there)

## Pull request checklist

- [ ] `make check` passes.
- [ ] `make fmt` produced no diff.
- [ ] New module has the top `/* … */` doc block.
- [ ] Any new firewall opening is annotated.
- [ ] Any new secret goes through sops-nix or a `*File =` option.
- [ ] Screenshots / GIFs attached if the PR changes the desktop UI.
