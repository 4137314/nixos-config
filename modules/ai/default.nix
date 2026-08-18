/*
  ai/default.nix — Local AI stack aggregator.

  Layers
  ------
    Inference       Ollama (chat + embeddings)
    UI              Open WebUI                        → ai.nixos-hacker-box
    Vector store    Qdrant                            → qdrant.nixos-hacker-box
    Speech out      Piper (OpenAI-compat TTS)         :10201
    Search          SearXNG (metasearch)              → search.nixos-hacker-box
    LLM search      Perplexica                        → perplex.nixos-hacker-box
    Agent workflows Flowise                           → flow-ai.nixos-hacker-box
    Domotics        Home Assistant                    → ha.nixos-hacker-box

  There is no speech-in layer: the host has no microphone. STT (Whisper)
  is intentionally omitted; see `ai/containers.nix` for how to add it.

  Every UI is fronted by Caddy (`network/caddy.nix`). Only Ollama's own
  API port (11434) is proxied for cross-host use.

  All these services are optional — comment individual imports below
  to opt out. The autonomous agents (`modules/agents/*`) depend on Ollama
  being reachable at http://127.0.0.1:11434 and will be no-ops
  otherwise (they poll and quietly retry).
*/
_: {
  imports = [
    ./ollama.nix
    ./open-webui.nix
    ./containers.nix
    ./home-assistant.nix
  ];
}
