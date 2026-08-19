/*
  ai/containers.nix — OCI containers for the AI stack.

  Everything here binds to loopback and is fronted by Caddy (see
  `network/caddy.nix`). Podman is the backend (enabled in
  `modules/development/default.nix`).

  Port map
  --------
    10201   piper-tts     OpenAI-compat TTS
    6333    qdrant        vector store (REST + web UI)
    6334    qdrant        gRPC
    8889    searxng       metasearch (privacy-first)
    3010    perplexica    LLM-powered search UI
    3009    flowise       visual agent workflows

  Speech-to-text (faster-whisper) is intentionally NOT deployed: this
  host has no microphone, so the container would idle. To re-introduce
  it, add a `whisper` service block below and the matching
  `AUDIO_STT_*` env vars in `ai/open-webui.nix`.

  State
  -----
  Container volumes live under `/var/lib/ai/<service>`, owned root:root.
  Covered by `restic` (see `modules/backup/restic.nix`).

  Networking
  ----------
  A dedicated `ai-search` podman network isolates the Perplexica ↔
  SearXNG pair. Other containers reach the host via `--add-host` and
  `host.containers.internal`.
*/
_:
let
  # ---- Common building blocks --------------------------------------------
  loopback = port: intPort: "127.0.0.1:${toString port}:${toString intPort}";

  # Every image is pulled lazily on first start.
  pullMissing = [ "--pull=missing" ];

  # Attach a container to the SearXNG/Perplexica isolated network.
  onSearchNet = [ "--network=ai-search" ];

  # `hostGateway` (--add-host=host.containers.internal:host-gateway) was
  # only needed by the currently disabled perplexica + flowise blocks.
  # Bring it back if you re-enable a container that must reach the host
  # loopback (e.g. Ollama at 127.0.0.1:11434 from inside a container):
  #   hostGateway = [ "--add-host=host.containers.internal:host-gateway" ];
in
{
  # Pinned explicitly so `ai/containers.nix` never silently falls back
  # to docker if `hub/containers.nix` (which also sets this) is disabled.
  virtualisation.oci-containers.backend = "podman";

  virtualisation.oci-containers.containers = {
    # ---------------------------------------------------------------------
    # Qdrant — vector database. Backbone of every RAG pipeline.
    # ---------------------------------------------------------------------
    qdrant = {
      image = "docker.io/qdrant/qdrant:latest";
      autoStart = true;
      ports = [
        (loopback 6333 6333)
        (loopback 6334 6334)
      ];
      volumes = [
        "/var/lib/ai/qdrant:/qdrant/storage"
        "/var/lib/ai/qdrant-snapshots:/qdrant/snapshots"
      ];
      environment = {
        QDRANT__SERVICE__HTTP_PORT = "6333";
        QDRANT__SERVICE__GRPC_PORT = "6334";
        QDRANT__TELEMETRY_DISABLED = "true";
      };
      extraOptions = pullMissing;
    };

    # ---------------------------------------------------------------------
    # Piper — high-quality neural TTS via OpenAI-compat wrapper.
    # ---------------------------------------------------------------------
    piper-tts = {
      image = "ghcr.io/matatonic/openedai-speech-min:latest";
      autoStart = true;
      ports = [ (loopback 10201 8000) ];
      volumes = [
        "/var/lib/ai/piper/voices:/app/voices"
        "/var/lib/ai/piper/config:/app/config"
      ];
      environment = {
        # Default voice bundle location; override per-request via `voice=`.
        TTS_HOME = "/app/voices";
      };
      extraOptions = pullMissing;
    };

    # ---------------------------------------------------------------------
    # SearXNG — metasearch. Feeds Perplexica + Open WebUI web-search.
    # ---------------------------------------------------------------------
    searxng = {
      image = "docker.io/searxng/searxng:latest";
      autoStart = true;
      ports = [ (loopback 8889 8080) ];
      volumes = [ "/var/lib/ai/searxng:/etc/searxng" ];
      environment = {
        BASE_URL = "https://search.nixos-hacker-box";
        INSTANCE_NAME = "hacker-box search";
        SEARXNG_SECRET_FILE = "/etc/searxng/secret";
      };
      extraOptions = pullMissing ++ onSearchNet;
    };

    # ---------------------------------------------------------------------
    # Perplexica — LLM-powered search UI (uses SearXNG + Ollama).
    # DISABLED — Perplexica needs a `config.toml` (bind, API URLs,
    # provider keys) at /var/lib/ai/perplexica/config/config.toml. Copy
    # the sample from https://github.com/ItzCrazyKns/Perplexica and edit,
    # then uncomment below.
    # ---------------------------------------------------------------------
    # perplexica = {
    #   image = "ghcr.io/itzcrazykns1337/perplexica:main";
    #   autoStart = true;
    #   dependsOn = [ "searxng" ];
    #   ports = [ (loopback 3010 3000) ];
    #   volumes = [
    #     "/var/lib/ai/perplexica/config:/home/perplexica/config"
    #     "/var/lib/ai/perplexica/data:/home/perplexica/data"
    #     "/var/lib/ai/perplexica/uploads:/home/perplexica/uploads"
    #   ];
    #   environment = {
    #     SEARXNG_API_URL = "http://searxng:8080";
    #     OLLAMA_API_URL = "http://host.containers.internal:11434";
    #     NEXT_PUBLIC_API_URL = "https://perplex.nixos-hacker-box/api";
    #     NEXT_PUBLIC_WS_URL = "wss://perplex.nixos-hacker-box";
    #   };
    #   extraOptions = pullMissing ++ onSearchNet ++ hostGateway;
    # };

    # ---------------------------------------------------------------------
    # Flowise — visual editor for LangChain agent workflows.
    # DISABLED — needs /var/lib/ai/flowise.env with:
    #   sudo install -d -o root -g root /var/lib/ai
    #   printf 'FLOWISE_PASSWORD=%s\n' "$(openssl rand -base64 24)" \
    #     | sudo install -m 0400 /dev/stdin /var/lib/ai/flowise.env
    # Then uncomment below.
    # ---------------------------------------------------------------------
    # flowise = {
    #   image = "docker.io/flowiseai/flowise:latest";
    #   autoStart = true;
    #   ports = [ (loopback 3009 3000) ];
    #   volumes = [ "/var/lib/ai/flowise:/root/.flowise" ];
    #   environmentFiles = [ "/var/lib/ai/flowise.env" ];
    #   environment = {
    #     PORT = "3000";
    #     DATABASE_PATH = "/root/.flowise";
    #     APIKEY_PATH = "/root/.flowise";
    #     SECRETKEY_PATH = "/root/.flowise";
    #     LOG_PATH = "/root/.flowise/logs";
    #     FLOWISE_USERNAME = "admin";
    #   };
    #   extraOptions = pullMissing ++ hostGateway;
    # };
  };

  # -----------------------------------------------------------------------
  # Podman networks needed by SearXNG + Perplexica.
  # -----------------------------------------------------------------------
  systemd.services.ai-networks = {
    description = "Ensure podman networks for AI containers exist";
    wantedBy = [ "multi-user.target" ];
    before = [
      "podman-searxng.service"
      "podman-perplexica.service"
    ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = [
        "/run/current-system/sw/bin/podman network create --ignore ai-search"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/ai                        0755 root root -"
    "d /var/lib/ai/qdrant                 0755 root root -"
    "d /var/lib/ai/qdrant-snapshots       0755 root root -"
    "d /var/lib/ai/piper                  0755 root root -"
    "d /var/lib/ai/piper/voices           0755 root root -"
    "d /var/lib/ai/piper/config           0755 root root -"
    "d /var/lib/ai/searxng                0755 root root -"
    "d /var/lib/ai/perplexica             0755 root root -"
    "d /var/lib/ai/perplexica/config      0755 root root -"
    "d /var/lib/ai/perplexica/data        0755 root root -"
    "d /var/lib/ai/perplexica/uploads     0755 root root -"
    "d /var/lib/ai/flowise                0755 root root -"
  ];
}
