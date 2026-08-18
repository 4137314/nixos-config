---
description: Run one of the on-box autonomous agents on demand and stream its output
argument-hint: "<log-analyzer | news-digest | finance-brief | incident-analyst>"
allowed-tools: Bash(sudo systemctl start:*), Bash(sudo systemctl status:*), Bash(sudo journalctl:*)
---

Trigger the autonomous agent **$ARGUMENTS** and stream its journal until
the run completes.

Sequence:

1. Confirm the agent name is one of:
   `log-analyzer`, `news-digest`, `finance-brief`, `incident-analyst`.
   If invalid, list valid ones and stop.

2. Fire the systemd unit:
   `sudo systemctl start agent-$ARGUMENTS.service`

3. Stream the journal until the service exits:
   `sudo journalctl -fu agent-$ARGUMENTS.service --since '1 minute ago'`
   Stop streaming when you see `agent[<name>] done at …` or when the
   service reports `Result: exit-code`.

4. Fetch and display the latest artifact from
   `/var/lib/agents/$ARGUMENTS/`:
   - log-analyzer → the ntfy body (no persistent file — just journal)
   - news-digest → `<date>-digest.md`
   - finance-brief → `<date>-brief.md`
   - incident-analyst → `<timestamp>/report.md` and its `snapshot.txt`

5. If the run failed, extract the last 40 journal lines and hand them
   to the operator with a one-sentence diagnosis (missing token file?
   Ollama unreachable? Loki empty?).

Never rerun the agent automatically if it failed — surface the cause.
