/*
  agents/observatory/default.nix — Aggregator for the observatory suite.

  Sub-modules
  -----------
    lib.nix       Shared CLIs (obs-ask, obs-ntfy, obs-event) + hardening.
                  Imported by every other file so the event bus schema
                  evolves in ONE place.
    passive.nix   Read-only agents: obs-doctor, obs-analyst, obs-triage,
                  obs-diary. Emit events on the shared bus.
    active.nix    Active agents: obs-healer, obs-janitor, obs-brain.
                  Consume events (via correlation_id) and act / summarise.
    rag.nix       obs-rag CLI over the Qdrant "observatory" collection.
    indexer.nix   Rebuilds the Qdrant collection every 4h.
    distill.nix   Opt-in CPU distillation (`obs-distill` CLI, no timer).
    metrics.nix   Prometheus counters via node_exporter textfile collector.

  This file only:
    * imports the sub-modules,
    * installs the shared CLI helpers system-wide,
    * declares the on-disk layout in one place (all state under
      `/var/lib/observatory`, group `users` readable).

  Bus events flow (ASCII)
  -----------------------
                                    events.jsonl
                                (append-only, flock)
                                        │
        publish  ┌──────────────┬───────┼────────┬──────────────┐  subscribe
                 ▼              ▼       ▼        ▼              ▼
             obs-doctor   obs-analyst obs-triage obs-diary  obs-healer
             obs-janitor  obs-brain                          (allowlist)
                                                            obs-brain
                                                            (meta)
                          ─────── RAG (Qdrant) ────────
                          obs-indexer  writes;  obs-rag reads
                          obs-brain    reads via `obs-rag query`

  Correlation model
  -----------------
  Each passive agent invents a per-run correlation_id and passes it on
  every publish. Downstream active agents inherit the id AND set
  --cause=<parent event id>, so `obs-event chain <id>` walks the whole
  workflow.
*/
{ pkgs, ... }:
let
  inherit (import ./lib.nix { inherit pkgs; })
    outputDir
    obs-ask
    obs-ntfy
    obs-event
    ;
in
{
  imports = [
    ./passive.nix
    ./active.nix
    ./rag.nix
    ./indexer.nix
    ./distill.nix
    ./metrics.nix
  ];

  environment.systemPackages = [
    obs-ask
    obs-ntfy
    obs-event
  ];

  # `obs-bus` is the write ACL for the event bus. Every publisher (all
  # observatory agents run as root; every topical agent from
  # `agents/{ops,personal,knowledge}` runs as `agent-<name>` with this
  # group appended in `agents/lib.nix`) is a member. Readers do not
  # need the group — the file is world-readable so `cat` / `jq` work
  # for the interactive user.
  users.groups.obs-bus = { };

  # Shared on-disk layout — passive.nix / active.nix declare their own
  # per-agent dirs; here we own the root + the bus file itself.
  systemd.tmpfiles.rules = [
    "d ${outputDir}                        0755 root users   -"
    "d ${outputDir}/doctor                 0755 root users   -"
    "d ${outputDir}/analyst                0755 root users   -"
    "d ${outputDir}/triage                 0755 root users   -"
    "d ${outputDir}/diary                  0755 root users   -"
    "f ${outputDir}/events.jsonl           0664 root obs-bus -"
    "f ${outputDir}/events.jsonl.lock      0664 root obs-bus -"
  ];
}
