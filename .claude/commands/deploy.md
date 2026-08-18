---
description: Safe deploy — runs make check, dry-activate, and prompts before make switch
argument-hint: "[optional message shown before switch]"
allowed-tools: Bash(make check), Bash(make dry), Bash(git diff:*), Bash(git status:*)
---

Deploy this NixOS configuration safely.

Sequence:

1. Run `make check` — if it fails, STOP and show the failure. Do not proceed.
2. Run `make dry` — surface the planned changes to the running system.
3. Summarise the diff between the current generation and the pending one in
   plain language: new services enabled, removed packages, kernel bumps,
   config changes that require attention (secrets to place, network shifts).
4. Report to the user with the summary and ask explicitly whether to proceed.

Never run `make switch` inside this command — surface the exact command for
the user to run manually. This preserves the "user pulls the trigger" model
for irreversible changes.

Optional context: $ARGUMENTS
