---
description: Report health + resource use of the local AI stack
allowed-tools: Bash(systemctl:*), Bash(curl:*), Bash(nvidia-smi:*), Bash(rocm-smi:*), Bash(free:*), Bash(ps:*)
---

Snapshot the local AI stack. Produce a table + brief prose.

Sequence:

1. **Ollama** — `curl -sf http://127.0.0.1:11434/api/tags | jq '.models[].name'`
   List loaded models. Include their size on disk.
   Also `ps -o rss= -C ollama` for resident memory (MB).

2. **Open WebUI** — `systemctl is-active open-webui.service` + last error
   from `journalctl -u open-webui -p err -n 10`.

3. **Containers** — for each of qdrant / whisper / piper-tts / searxng /
   perplexica / flowise: `systemctl is-active podman-<name>.service`
   plus `curl -sf http://127.0.0.1:<port>/` liveness (any 2xx/3xx = ok).

4. **Home Assistant** — `systemctl is-active home-assistant`.

5. **Autonomous agents** — for each agent-<name> unit: last invocation
   timestamp from `systemctl show agent-<name>.service -p ActiveEnterTimestamp`,
   exit code, next scheduled run from the associated timer.

6. **Host resources** — `free -h` + `ps -o rss=,comm= --sort=-rss | head -10`.

Output format:

```
### Ollama
  loaded models: llama3.2:3b, qwen2.5:14b, …   RSS: <MB>

### UI / Containers
  | service      | status | port  | last error |
  |--------------|--------|-------|------------|
  | open-webui   | active | 8080  | -          |
  | qdrant       | active | 6333  | -          |
  ...

### Agents
  | agent            | last run            | exit | next run          |
  |------------------|---------------------|------|-------------------|
  | log-analyzer     | 2026-08-18 09:00    | 0    | 2026-08-18 10:00  |
  ...

### Host
  RAM used/total: 12/32 GiB   top 5 processes by RSS: …
```

End with a one-line verdict — `all green`, `degraded (details above)`,
or `critical (specific failure)`.
