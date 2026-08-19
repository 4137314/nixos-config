/*
  agents/default.nix — Top-level aggregator for the autonomous agent suites.

  Sub-suites (each importable independently)
  ------------------------------------------
    observatory/    Self-observation. Doctor, analyst, triage, diary,
                    healer, janitor, indexer, brain, metrics, RAG, distill.
                    Always safe to enable — pure read + hardened.

    ops/            Infra/ops LLM pipelines (log-analyzer, news-digest,
                    finance-brief, incident-analyst). Needs external
                    tokens (see prerequisites below).

    personal/       Life-facing LLM pipelines (weekly-reflection, doc
                    classifier, bookmark summariser, calendar briefer,
                    health nudger). Needs Nextcloud / Karakeep / HA up.

    knowledge/      Cross-service RAG indexer over user data (Notes,
                    bookmarks, Memos, Silverbullet, personal repos).

  Enabling individual suites
  --------------------------
  Import ONLY what you need in configuration.nix, e.g.:
      ./modules/agents/observatory
      ./modules/agents/ops
      # ./modules/agents/personal   # add once Nextcloud is running
      # ./modules/agents/knowledge  # add once Karakeep is running

  Or import this whole file (`./modules/agents`) to pull everything at
  once — the default here is CONSERVATIVE: only `observatory` is
  imported so a fresh install can't fail on missing tokens.

  Shared plumbing
  ---------------
  Every topical agent in ops/, personal/, knowledge/ is built via
  `mkAgent` from `agents/lib.nix`, which:
    * runs the pipeline under a dedicated `agent-<name>` system user,
    * grants that user membership in `obs-bus` so it can publish
      `run_start` / `run_completed` / `run_failed` events on the
      observatory event bus (see `observatory/lib.nix` for the schema),
    * exposes OLLAMA_URL, NTFY_URL, LOKI_URL, STATE_DIR, HOSTNAME to
      the pipeline body.

  Wiring the tokens (once, before enabling ops/ or personal/)
  ------------------------------------------------------------
      # ntfy bearer for authenticated push from every agent
      echo -n "tk_..." | sudo tee /var/lib/agents/ntfy-token >/dev/null
      sudo chmod 400 /var/lib/agents/ntfy-token

      # Miniflux API key (Miniflux UI → Settings → API Keys)
      echo -n "1|abc..." | sudo tee /var/lib/agents/miniflux-token >/dev/null
      sudo chmod 400 /var/lib/agents/miniflux-token

      # Ghostfolio access token
      echo -n "eyJ..." | sudo tee /var/lib/agents/ghostfolio-token >/dev/null
      sudo chmod 400 /var/lib/agents/ghostfolio-token

  Manual dry-run of any agent:
      sudo systemctl start agent-<name>
      sudo journalctl -fu agent-<name>
*/
_: {
  imports = [
    ./observatory
    # Uncomment as prerequisites are met:
    # ./ops
    # ./personal
    # ./knowledge
  ];

  # State root for topical agents. Individual `mkAgent` invocations create
  # per-agent 0750 subdirs. Parent is 0755 so agents can traverse it.
  systemd.tmpfiles.rules = [
    "d /var/lib/agents 0755 root root -"
  ];
}
