/*
  agents/ops/default.nix — Infrastructure / operations agents.

  Each agent is a hardened systemd oneshot (see `../lib.nix` → mkAgent).
  Because mkAgent injects `obs-event`, every run automatically emits
  `run_start` / `run_completed` / `run_failed` events onto the shared
  observatory bus — no per-agent wiring required.

  Members
  -------
    log-analyzer       hourly     Loki  → LLM triage → ntfy `system`
    news-digest        daily      Miniflux → LLM → ntfy `news`
    finance-brief      weekdays   Ghostfolio + external quotes → LLM → ntfy `finance`
    incident-analyst   on-demand  systemd + journal → LLM → ntfy `system`

  Enable by importing this file in configuration.nix — but only after
  the prerequisite tokens exist under /var/lib/agents/ (see the
  top-level `agents/default.nix` docstring).
*/
_: {
  imports = [
    ./log-analyzer.nix
    ./news-digest.nix
    ./finance-brief.nix
    ./incident-analyst.nix
  ];
}
