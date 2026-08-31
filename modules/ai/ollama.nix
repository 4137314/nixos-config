/*
  ai/ollama.nix — Local LLM inference server (CPU inference).

  Hardware target
  ---------------
  Ryzen desktop, RX 470 (gfx803 / GCN 4 Polaris), 48 GB system RAM.

  GPU note
  --------
  The RX 470 (gfx803) is not supported by the ROCm backend shipped in
  Ollama 0.21+. Enabling `acceleration = "rocm"` causes a hard crash
  ("ggml_cuda_compute_forward: RMS_NORM failed — ROCm error: invalid
  device function") because Ollama's ROCm build no longer includes
  compiled kernels for gfx803. CPU inference is used instead:
    - AVX2 + FMA available (confirmed from boot log)
    - 36+ GB RAM free → 3B–7B Q4_K_M models load and run fine
    - ~10–20 tok/s on 3B; ~4–8 tok/s on 7B — adequate for agent use

  To revisit GPU when upgrading Ollama: test with
    HSA_OVERRIDE_GFX_VERSION=9.0.0 ROC_ENABLE_PRE_VEGA=1 ollama serve

  Model set (Q4_K_M, CPU-sized)
  ------------------------------
    llama3.2:3b         fast tool calls / quick answers    (~2 GB)
    qwen2.5:7b          general reasoning                  (~5 GB)
    qwen2.5-coder:7b    code / Nix / bash                  (~5 GB)
    nomic-embed-text    embeddings (RAG, Observatory)      (~300 MB)

  Pull larger models on demand:
    ollama pull qwen2.5-coder:14b   # ~9 GB, needs ≥10 GB free RAM
    ollama pull deepseek-r1:8b      # ~5 GB, chain-of-thought
*/
_: {
  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    port = 11434;

    # CPU inference — gfx803 (RX 470) unsupported by Ollama 0.21 ROCm build.
    acceleration = null;

    environmentVariables = {
      OLLAMA_KEEP_ALIVE = "45m";
      OLLAMA_NUM_PARALLEL = "2";
      OLLAMA_MAX_LOADED_MODELS = "2";
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
      OLLAMA_CONTEXT_LENGTH = "8192";
      OLLAMA_ORIGINS = "https://*.nixos-hacker-box,http://localhost:*";
    };

    loadModels = [
      "llama3.2:3b"
      "qwen2.5:7b"
      "qwen2.5-coder:7b"
      "nomic-embed-text"
    ];
  };
}
