/*
  configuration.nix — System-level NixOS entry point.

  This file is an import list only. Every concern lives in its own module.
  To add or disable a feature, add or remove the relevant line below.

  Module tree
  ───────────────────────────────────────────────────────────────────────
  modules/hardware/         hardware-configuration.nix + audio + RGB + AMD GPU
  modules/system/           boot, networking, users, Nix daemon, SSH+2FA,
                            fail2ban, sops secrets, hardening, resilience,
                            peripherals, journald, smart, attic-cache
  modules/workstation/      desktop environment, shell, system packages
  modules/development/      Compilers, LSPs, containers, virtualisation
  modules/security/         Pentest toolkit + wordlists + audit + aide + suricata
  modules/nas/              Btrfs storage, Samba, Syncthing
  modules/media/            Jellyfin, arr-stack (disabled)
  modules/cloud/            Nextcloud + PostgreSQL + Redis + Forgejo
  modules/network/          Tailscale, AdGuard, Caddy TLS, Tor onion
  modules/monitoring/       Prometheus + Grafana + Loki + ntfy + alerts +
                            VictoriaMetrics + app scrapes
  modules/backup/           restic + btrbk + postgres dumps + weekly verify
  modules/hub/              Personal digital hub (18+ services)
  modules/ai/               Ollama (ROCm) + Open WebUI + Qdrant + Piper +
                            SearXNG + Perplexica + Flowise + HA
                            (IoT / Frigate / Whisper opt-in — see below)
  modules/agents/           10 autonomous LLM pipelines

  Hardware footprint
  ------------------
  This desktop has no microphone, no Bluetooth radio and no external
  physical sensors. STT (Whisper), the Bluetooth stack and IoT hubs
  are therefore deliberately absent from the enabled set; the modules
  are kept around (or documented as easy to re-add) so a future hardware
  upgrade only needs one line flipped.

  DISABLED (commented) modules — enable one at a time when prerequisites
  are met. See "Post-switch enable" comments next to each.
*/
_: {
  imports = [
    # Hardware — hardware-configuration.nix, audio, RGB, AMD GPU + ROCm
    ./modules/hardware

    # System identity
    ./modules/system/boot.nix
    ./modules/system/networking.nix
    ./modules/system/users.nix
    ./modules/system/nix.nix

    # System reliability, hardening, and secrets
    ./modules/system/resilience.nix
    ./modules/system/hardening.nix
    ./modules/system/openssh.nix
    ./modules/system/fail2ban.nix
    ./modules/system/secrets.nix
    ./modules/system/peripherals.nix
    ./modules/system/journald.nix
    ./modules/system/smart.nix
    ./modules/system/modes.nix

    # ./modules/system/attic-cache.nix   # enable after generating /var/lib/atticd/env

    # Desktop workstation
    ./modules/workstation/display.nix
    ./modules/workstation/shell.nix
    ./modules/workstation/packages.nix

    # Development toolchain (compilers, LSPs, containers, VMs)
    ./modules/development

    # Offensive-security toolkit (pentest / bug bounty / CTF)
    ./modules/security/pentest.nix
    ./modules/security/wordlists.nix
    ./modules/security/audit.nix
    # ./modules/security/aide.nix          # disabled — AIDE 0.19 config
    # parser in nixpkgs rejects both `database=file:/path` and bare `database=/path`.
    # Re-enable once the correct syntax is validated with `aide --config-check`.
    # ./modules/security/suricata.nix    # enable to route enp4s0 through IDS

    # NAS — storage layout, file sharing, sync
    ./modules/nas/storage.nix
    ./modules/nas/samba.nix
    ./modules/nas/syncthing.nix

    # Media stack
    ./modules/media/jellyfin.nix
    # ./modules/media/arr-stack.nix      # disabled — needs VPN creds

    # Personal cloud
    ./modules/cloud/nextcloud.nix
    ./modules/cloud/forgejo.nix

    # Network & security
    ./modules/network/tailscale.nix
    ./modules/network/adguard.nix
    ./modules/network/caddy.nix
    # ./modules/network/tor.nix          # enable to expose onion services

    # Observability
    ./modules/monitoring/observability.nix
    ./modules/monitoring/loki.nix
    ./modules/monitoring/ntfy.nix
    ./modules/monitoring/alerts.nix
    ./modules/monitoring/victoriametrics.nix
    ./modules/monitoring/app-scrapes.nix

    # Backup and offsite replication
    ./modules/backup/restic.nix
    ./modules/backup/postgres.nix
    ./modules/backup/verify.nix
    # ./modules/backup/btrbk.nix         # needs second Btrfs disk at /mnt/backup

    # Personal Hub — news / RSS / photos / docs / passwords / tasks /
    # notes / finance / automation / dashboard / knowledge / scraping.
    ./modules/hub

    # AI stack — Ollama (ROCm), Open WebUI, Qdrant, Piper (TTS),
    # SearXNG, Perplexica, Flowise, Home Assistant.
    # STT (faster-whisper) is deliberately omitted — no microphone.
    ./modules/ai
    # ./modules/ai/iot.nix               # enable after plugging Zigbee coordinator
    # ./modules/ai/frigate.nix           # enable after adding IP cameras

    # Autonomous LLM pipelines — enable one at a time as agent tokens are
    # provisioned in /var/lib/agents/.
    # ./modules/agents

    # Observatory suite — modularised self-reflective agent system.
    # See modules/agents/observatory/default.nix for the ASCII diagram
    # of how passive/active agents talk over the shared event bus with
    # correlation + causation IDs. Split into:
    #   lib.nix       shared CLIs (obs-ask, obs-ntfy, obs-event)
    #   passive.nix   doctor, analyst, triage, diary
    #   active.nix    healer (allowlist+cooldown), janitor, brain
    #   rag.nix       obs-rag query CLI (Qdrant)
    #   indexer.nix   4-hourly Qdrant re-index
    #   distill.nix   opt-in CPU distillation (no timer)
    #   metrics.nix   Prometheus counters via textfile collector
    ./modules/agents/observatory
  ];
}
