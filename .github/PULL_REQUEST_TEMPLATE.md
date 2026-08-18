<!--
  Thanks for the PR. Fill in the sections below so review is fast.
-->

## Summary

<!-- What changes and why. One paragraph. -->

## Type

- [ ] `feat` — new capability
- [ ] `fix` — bug fix
- [ ] `refactor` — no behaviour change
- [ ] `docs` — documentation only
- [ ] `chore` — deps, tooling, CI
- [ ] `sec` — security-relevant

## Checklist

- [ ] `make check` passes locally
- [ ] `make fmt` produced no diff
- [ ] Doc block present on new modules
- [ ] Firewall openings annotated (if any)
- [ ] Secrets are file-referenced, never inline
- [ ] CLAUDE.md / README.md updated if user-facing behaviour changed

## Deployment notes

<!--
  Anything the operator has to do BEFORE / AFTER `make switch`:
    - place a secret file
    - init a database
    - open a browser to complete a wizard
-->

## Rollback plan

<!--
  How to back out cleanly if this misbehaves in production. Default:
  `sudo nixos-rebuild switch --rollback`.
-->
