---
description: Decompose a task across Pi subagents and synthesize the results
argument-hint: "<task description>"
allowed-tools: Bash(pi:*), Bash(cat:*), Bash(ls:*)
---

Decompose **$ARGUMENTS** across the available Pi agents and produce a
synthesized result.

## Agent roster

| Agent            | Invocation   | Best for                            |
| ---------------- | ------------ | ----------------------------------- |
| `hacker-box`     | `piq "…"`    | system queries, orchestration       |
| `dev-scout`      | `pidev "…"`  | code investigation + implementation |
| `nix-scout`      | `picode "…"` | read-only NixOS module inspection   |
| `web-recon`      | `piweb "…"`  | external docs, changelogs, CVEs     |
| `service-doctor` | `pisys "…"`  | systemd/log triage                  |

## Process

1. **Analyse** the task. Break it into ≤5 subtasks. For each subtask
   identify which agent handles it best.

2. **Run** each subtask sequentially using the invocation in the table
   above (one-shot `-p` flag). Capture the output.

3. **Synthesize** the outputs into a single coherent response with:
   - What was found / done
   - Any files changed or commands to run
   - Open questions or next steps

4. If the task requires code changes: prefer `dev-scout` for the
   implementation, `nix-scout` for read-only pre-flight, and always end
   with `make check` before suggesting a switch.

Keep the total number of Pi invocations ≤ 8 to avoid token bloat.
