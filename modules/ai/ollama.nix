/*
  ai/ollama.nix — Local LLM inference server on AMD ROCm.

  Hardware target
  ---------------
  Ryzen desktop, AMD dGPU with ~8 GB VRAM, 48 GB system RAM.
  Acceleration set to "rocm" — Ollama offloads as many layers as fit
  in VRAM, spills the rest to CPU/RAM automatically.

  Model set (Q4_K_M quantisation, sized for the hardware)
  --------------------------------------------------------
    llama3.2:3b            fast agent / tool call    (~2 GB, full GPU)
    qwen2.5:14b            reasoning / summarise     (~9 GB, mostly GPU)
    qwen2.5-coder:14b      code / Nix / bash         (~9 GB, mostly GPU)
    deepseek-r1:14b        chain-of-thought          (~9 GB, mostly GPU)
    nomic-embed-text       fast embeddings           (~300 MB)
    mxbai-embed-large      accurate embeddings       (~700 MB)
    llava:13b              vision-language           (~8 GB, mostly GPU)

  Speculative decoding (draft model) is configured per-request via
  Open WebUI or the API — set `draft_model: "llama3.2:3b"` when calling
  qwen2.5:14b for a ~2-3x tokens/sec speedup with no quality drop.

  Storage
  -------
  /var/lib/ollama holds ~40 GB of models. Excluded from restic
  (rebuildable via `ollama pull`).

  ROCm gotchas
  ------------
  If Ollama refuses to see the GPU at first boot, adjust `HSA_OVERRIDE_
  GFX_VERSION` in the env vars below:
    RDNA3 (7000-series)  → 11.0.0    (default here)
    RDNA2 (6000-series)  → 10.3.0
    RDNA1 (5000-series)  → 10.1.0
  Also verify `rocminfo` sees the card (rocm-smi shows utilisation).
*/
_: {
  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    port = 11434;

    # AMD GPU via ROCm.
    acceleration = "rocm";

    environmentVariables = {
      OLLAMA_KEEP_ALIVE = "45m";
      OLLAMA_NUM_PARALLEL = "2";
      OLLAMA_MAX_LOADED_MODELS = "2";
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
      OLLAMA_CONTEXT_LENGTH = "8192";
      OLLAMA_ORIGINS = "https://*.nixos-hacker-box,http://localhost:*";

      # Polaris (RX 470/480/570/580/590 = GCN 4) — ROCm doesn't officially
      # support it, but with the two env vars below the OpenCL backend
      # runs. Big models still fall back to CPU; keep loadModels small.
      HSA_OVERRIDE_GFX_VERSION = "8.0.3";
      ROC_ENABLE_PRE_VEGA = "1";
      HIP_VISIBLE_DEVICES = "0";
    };

    # Small model set tuned for CPU-first inference on a Polaris + 48 GB RAM.
    # Add larger models via `ollama pull qwen2.5:14b` after verifying the
    # first three work well on this hardware.
    loadModels = [
      "llama3.2:3b" # ~2 GB, fast, works fully on GPU
      "qwen2.5:7b" # ~5 GB, reasoning at usable speed
      "qwen2.5-coder:7b" # ~5 GB, coding helper
      "nomic-embed-text" # embeddings, tiny
    ];
  };
}
