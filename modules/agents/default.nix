/*
  agents/default.nix — Autonomous LLM pipelines.

  Each agent is a self-contained NixOS systemd unit that periodically
  wakes up, gathers data from local services, asks Ollama for
  structured output, and publishes to ntfy.

    log-analyzer      hourly    Loki    → LLM → ntfy `system`
    news-digest       daily     Miniflux → LLM → ntfy `news`
    finance-brief     weekdays  Ghostfolio + Yahoo/CoinGecko → LLM → ntfy `finance`
    incident-analyst  on-demand systemd + journal → LLM → ntfy `system`

  All agents run under dedicated system users `agent-<name>` with a
  hardened systemd sandbox. State lives in /var/lib/agents/<name>/.
  Secrets (Miniflux token, Ghostfolio token, ntfy bearer token) are
  read from files under /var/lib/agents/ owned by root, mode 400, and
  bind-mounted read-only into each agent via NixOS's default systemd
  isolation.

  Wiring the tokens (once)
  ------------------------
      # ntfy bearer for cross-agent authenticated push
      echo -n "tk_..." | sudo tee /var/lib/agents/ntfy-token >/dev/null
      sudo chmod 400 /var/lib/agents/ntfy-token

      # Miniflux API key (from Miniflux UI → Settings → API Keys)
      echo -n "1|abc..." | sudo tee /var/lib/agents/miniflux-token >/dev/null
      sudo chmod 400 /var/lib/agents/miniflux-token

      # Ghostfolio access token
      echo -n "eyJ..." | sudo tee /var/lib/agents/ghostfolio-token >/dev/null
      sudo chmod 400 /var/lib/agents/ghostfolio-token

  Manual dry-run of any agent (as root):
      sudo systemctl start agent-<name>
      sudo journalctl -fu agent-<name>
*/
_: {
  imports = [
    # Infrastructure / operations agents
    ./log-analyzer.nix
    ./news-digest.nix
    ./finance-brief.nix
    ./incident-analyst.nix

    # Personal / life agents
    ./weekly-reflection.nix
    ./document-classifier.nix
    ./bookmark-summariser.nix
    ./calendar-briefer.nix
    ./health-nudger.nix

    # Cross-service RAG indexer
    ./rag-indexer.nix
  ];

  # State root — the individual mkAgent invocations create per-agent
  # subdirs. The parent is 0755 root:root so agents can traverse it.
  systemd.tmpfiles.rules = [
    "d /var/lib/agents 0755 root root -"
  ];
}
