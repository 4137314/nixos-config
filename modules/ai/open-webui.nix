/*
  ai/open-webui.nix — ChatGPT-style multi-user UI for local LLMs.

  Features enabled
  ----------------
  Chat with Ollama models         → conversational interface
  RAG over uploaded documents     → per-workspace knowledge bases
  Web search integration          → routes through SearXNG
  Text-to-speech (TTS)            → Piper (ai/containers.nix)
  Tools / function calling        → shell, HTTP, Python sandbox

  Voice input (STT / Whisper) is NOT wired: this host has no
  microphone. TTS remains — the browser can still read chat replies
  aloud through the desktop speakers.

  Access
  ------
  http://127.0.0.1:8080 direct, https://ai.nixos-hacker-box behind Caddy.

  First-run
  ---------
  1. First user to register becomes the admin.
  2. Settings → Admin Panel → General → Signup: turn OFF after your account.
  3. Settings → Connections → Ollama: URL http://127.0.0.1:11434 (auto).
  4. Settings → Documents → Embedding model: nomic-embed-text (from Ollama).
  5. Settings → Web Search → SearXNG URL:
       http://127.0.0.1:8889/search?q=<query>
  6. Settings → Audio → TTS: Piper endpoint http://127.0.0.1:10201/v1
     (leave STT set to "None").

  Data
  ----
  `/var/lib/open-webui` — user accounts, chat history, uploaded documents,
  vector index (SQLite + Chroma). Covered by restic.
*/
_: {
  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 8080;

    environment = {
      # LLM backend.
      OLLAMA_BASE_URL = "http://127.0.0.1:11434";
      ENABLE_OPENAI_API = "False";

      # RAG / embeddings (served by Ollama).
      RAG_EMBEDDING_ENGINE = "ollama";
      RAG_EMBEDDING_MODEL = "nomic-embed-text";
      RAG_OLLAMA_BASE_URL = "http://127.0.0.1:11434";
      RAG_TOP_K = "5";
      CHUNK_SIZE = "1500";
      CHUNK_OVERLAP = "150";

      # Web search backend — SearXNG on the same host.
      ENABLE_RAG_WEB_SEARCH = "True";
      RAG_WEB_SEARCH_ENGINE = "searxng";
      SEARXNG_QUERY_URL = "http://127.0.0.1:8889/search?q=<query>";
      RAG_WEB_SEARCH_RESULT_COUNT = "5";
      RAG_WEB_SEARCH_CONCURRENT_REQUESTS = "10";

      # Text-to-speech only — no microphone on this host, so STT is off.
      AUDIO_TTS_ENGINE = "openai";
      AUDIO_TTS_OPENAI_API_BASE_URL = "http://127.0.0.1:10201/v1";
      AUDIO_TTS_OPENAI_API_KEY = "not-needed-local";
      AUDIO_TTS_MODEL = "tts-1";
      AUDIO_TTS_VOICE = "it_IT-riccardo-x_low";

      # Multi-user hygiene.
      DEFAULT_USER_ROLE = "pending"; # admin must approve new accounts
      ENABLE_SIGNUP = "True"; # flip to False after first account
      WEBUI_AUTH = "True";
      WEBUI_SESSION_COOKIE_SECURE = "True";
      WEBUI_SESSION_COOKIE_SAME_SITE = "strict";
      ENABLE_ADMIN_EXPORT = "True";

      # Telemetry — hard off.
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "1";
      SCARF_NO_ANALYTICS = "true";
    };
  };
}
