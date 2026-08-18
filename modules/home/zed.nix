/*
  home/zed.nix — Zed editor with local Ollama integration.

  Why Zed alongside Neovim + VS Code
  ----------------------------------
  Zed is Rust-based, GPU-rendered, and has AI assistant that speaks a
  generic OpenAI-compat endpoint — perfect for pointing at Ollama. Very
  fast for large refactors; keep Neovim for terminal-only work and VS
  Code for extension-heavy debugging.

  AI config
  ---------
  Uses `qwen2.5-coder:14b` for inline completion + agent chat. Points
  at the local Ollama server (:11434). No cloud traffic.
*/
{ unstable, ... }:
{
  home.packages = [ unstable.zed-editor ];

  # Declarative user settings — Zed reads ~/.config/zed/settings.json.
  xdg.configFile."zed/settings.json".text = builtins.toJSON {
    theme = {
      mode = "system";
      dark = "One Dark";
      light = "One Light";
    };
    buffer_font_family = "JetBrainsMono Nerd Font";
    buffer_font_size = 13;
    ui_font_family = "JetBrainsMono Nerd Font";

    telemetry = {
      metrics = false;
      diagnostics = false;
    };

    # Language model provider — Ollama at localhost.
    language_models = {
      ollama = {
        api_url = "http://127.0.0.1:11434";
        available_models = [
          {
            name = "qwen2.5-coder:14b";
            max_tokens = 32768;
          }
          {
            name = "qwen2.5:14b";
            max_tokens = 32768;
          }
          {
            name = "llama3.2:3b";
            max_tokens = 8192;
          }
          {
            name = "deepseek-r1:14b";
            max_tokens = 32768;
          }
        ];
      };
    };

    assistant = {
      default_model = {
        provider = "ollama";
        model = "qwen2.5-coder:14b";
      };
      version = "2";
    };

    inline_completions = {
      provider = "supermaven"; # Zed's local completion, not cloud
      disabled_globs = [
        "**/.env"
        "**/*secret*"
      ];
    };

    features = {
      inline_completion_provider = "none"; # opt-in per-project via toggle
    };

    format_on_save = "on";
    formatter = "language_server";
    tab_size = 2;
  };
}
