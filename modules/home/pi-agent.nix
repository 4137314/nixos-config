/*
  home/pi-agent.nix — Pi Coding Agent (https://pi.dev) with local Ollama.

  Pi is an MIT-licensed CLI coding agent (like aider / cursor / claude-code)
  that supports 15+ LLM providers, INCLUDING an OpenAI-compatible endpoint
  we can point at our local Ollama at 127.0.0.1:11434 — so every session
  runs 100% locally on this box, no cloud tokens.

  Why Home Manager and not a system package
  -----------------------------------------
  Pi is npm-only (`@earendil-works/pi-coding-agent`) and not yet in nixpkgs.
  Rather than write a `buildNpmPackage` derivation that we'd have to update
  by hand on every release, we do a one-shot `npm install` into
  `~/.local/pi/` at Home-Manager activation time. This keeps:
    * the binary reachable via a normal `pi` on $PATH (session-path
      injection below);
    * the versioning under Pi's own auto-update flow inside its dir;
    * zero interaction with the Nix store (nothing lands in /nix).

  How to use, once activated
  --------------------------
  1. Wait for `home-manager-main.service` to finish (or run
     `home-manager switch` manually the first time).
  2. `pi` — launches the interactive TUI, pointed at Ollama by default.
  3. `pi --model qwen2.5-coder:7b` — override model per session.
  4. See ~/.config/pi/config.json for the provider set-up we ship;
     add API keys there for OpenAI / Anthropic / … when you want to
     compare a run against a frontier model.

  Repo-level agent instructions
  -----------------------------
  Pi picks up a top-level `AGENTS.md` in the working directory as
  project instructions (its analogue to CLAUDE.md). We already ship
  a CLAUDE.md; the AGENTS.md link we place is a symlink pointing to
  it so both assistants read the same rules — no drift.
*/
{
  pkgs,
  lib,
  config,
  ...
}:
let
  piDir = "${config.home.homeDirectory}/.local/pi";
  piBin = "${piDir}/node_modules/.bin";

  # OpenAI-compatible endpoint speakable by Ollama at /v1.
  # Pi's default OpenAI provider reads OPENAI_BASE_URL + OPENAI_API_KEY,
  # so this is the minimum working configuration for local-first use.
  piConfig = {
    default_provider = "ollama-openai";
    providers = {
      ollama-openai = {
        # Ollama exposes an OpenAI-compatible surface at /v1 since v0.1.24.
        base_url = "http://127.0.0.1:11434/v1";
        # Pi will send `Authorization: Bearer <key>`; Ollama ignores it
        # but the client refuses to talk without one being set.
        api_key = "ollama-local-not-a-secret";
        # Recommended default for Polaris-class GPUs — 7B fits comfortably;
        # coder variant is auto-picked for code sessions by the router.
        model = "qwen2.5:7b";
      };
    };
    # Route code-heavy sessions to the coder variant when available.
    routing = {
      code = "qwen2.5-coder:7b";
      chat = "qwen2.5:7b";
      quick = "llama3.2:3b";
    };
    telemetry.enabled = false;
  };
in
{
  # `nodejs_22` is already in home/packages.nix; not duplicated here.

  # Ship the provider config so `pi` works out of the box against Ollama.
  # User can edit ~/.config/pi/config.json to add cloud keys later.
  xdg.configFile."pi/config.json".text = builtins.toJSON piConfig;

  home = {
    # Put Pi's local binary on the user's PATH.
    sessionPath = [ piBin ];

    activation = {
      # Symlink AGENTS.md → CLAUDE.md at repo root so pi + Claude Code
      # share the same behavioural instructions. Idempotent: only
      # creates the symlink if it doesn't exist AND the target does.
      pi-link-agents-md = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -f /etc/nixos/CLAUDE.md ] && [ ! -e /etc/nixos/AGENTS.md ]; then
          $DRY_RUN_CMD ln -sf CLAUDE.md /etc/nixos/AGENTS.md
        fi
      '';

      # One-shot install (or update) at every Home Manager activation.
      # Cheap when up-to-date — npm checks the local package.json first.
      pi-install = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        export PATH="${pkgs.nodejs_22}/bin:$PATH"
        $DRY_RUN_CMD install -d "${piDir}"
        if [ ! -f "${piDir}/package.json" ]; then
          $DRY_RUN_CMD ${pkgs.nodejs_22}/bin/npm init -y \
            --prefix "${piDir}" >/dev/null
        fi
        # `--ignore-scripts` matches upstream's install instructions
        # (avoids running arbitrary postinstall from transitive deps).
        $DRY_RUN_CMD ${pkgs.nodejs_22}/bin/npm install \
          --prefix "${piDir}" \
          --ignore-scripts --no-audit --no-fund --loglevel=error \
          @earendil-works/pi-coding-agent
      '';
    };
  };
}
