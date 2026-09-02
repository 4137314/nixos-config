/*
  home/pi-agent.nix — Pi Coding Agent (https://pi.dev) with local Ollama.

  Pi is an MIT-licensed terminal coding harness. It loads global settings
  from ~/.pi/agent/settings.json, custom provider/model entries from
  ~/.pi/agent/models.json, and agent definitions from ~/.pi/agent/agents/.

  This module keeps the default path local-first:
    - provider `ollama` points at http://127.0.0.1:11434/v1;
    - no real cloud keys are written by Nix;
    - cloud providers become available later via Pi's /login or auth.json;
    - pi-open-agents is declared as a Pi package for primary agents and
      isolated subagents with per-agent model/thinking/permission settings.

  Pi itself is npm-only (`@earendil-works/pi-coding-agent`) and not yet in
  nixpkgs. Home Manager installs it into ~/.local/pi during activation and
  exposes ~/.local/pi/node_modules/.bin on PATH.
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

  zeroCost = {
    input = 0;
    output = 0;
    cacheRead = 0;
    cacheWrite = 0;
  };

  cloudModel =
    {
      id,
      name,
      contextWindow,
      maxTokens,
      reasoning ? false,
      inputTypes ? [
        "text"
        "image"
      ],
      costInput,
      costOutput,
      costCacheRead ? 0,
      costCacheWrite ? 0,
    }:
    {
      inherit
        id
        name
        contextWindow
        maxTokens
        reasoning
        ;
      input = inputTypes;
      cost = {
        input = costInput;
        output = costOutput;
        cacheRead = costCacheRead;
        cacheWrite = costCacheWrite;
      };
    };

  localModel =
    {
      id,
      name,
      contextWindow ? 8192,
      maxTokens ? 4096,
      temperature ? 0.25,
      topP ? 0.9,
    }:
    {
      inherit
        id
        name
        contextWindow
        maxTokens
        ;
      reasoning = false;
      input = [ "text" ];
      cost = zeroCost;
      samplingParams = {
        inherit temperature;
        top_p = topP;
      };
    };

  piSettings = {
    defaultProvider = "ollama";
    defaultModel = "qwen2.5:7b";
    defaultThinkingLevel = "low";
    defaultAgent = "hacker-box";

    enabledModels = [
      # Local (Ollama — always available, zero cost)
      "ollama/qwen2.5:7b:low"
      "ollama/qwen2.5-coder:7b:low"
      "ollama/qwen2.5-coder:14b:low"
      "ollama/deepseek-r1:8b:low"
      "ollama/llama3.2:3b:off"
      # Anthropic cloud (requires ANTHROPIC_API_KEY in env)
      "anthropic/claude-haiku-4-5-20251001:low"
      "anthropic/claude-sonnet-4-6:high"
      "anthropic/claude-opus-4-7:high"
      # OpenAI cloud (requires OPENAI_API_KEY in env)
      "openai/gpt-4o:medium"
      "openai/o4-mini:medium"
    ];

    modelThinkingLevels = {
      "ollama/llama3.2:3b" = "off";
      "ollama/qwen2.5:7b" = "low";
      "ollama/qwen2.5-coder:7b" = "low";
      "anthropic/claude-haiku-4-5-20251001" = "low";
      "anthropic/claude-sonnet-4-6" = "high";
      "anthropic/claude-opus-4-7" = "high";
      "openai/gpt-4o" = "medium";
      "openai/o4-mini" = "medium";
    };

    packages = [ "npm:pi-open-agents" ];
    npmCommand = [ "${pkgs.nodejs_22}/bin/npm" ];

    theme = "dark";
    tuiMode = "fullscreen";
    fullscreenExitOutput = "resume-hint";
    fullscreenScrollbar = "auto";
    fullscreenCopyOnSelect = false;
    quietStartup = true;
    collapseChangelog = true;
    defaultProjectTrust = "ask";
    doubleEscapeAction = "tree";
    treeFilterMode = "default";
    editorPaddingX = 1;
    outputPad = 1;
    autocompleteMaxVisible = 8;
    externalEditor = "nvim";

    enableInstallTelemetry = false;
    enableAnalytics = false;

    terminal = {
      showImages = true;
      imageWidthCells = 56;
      clearOnShrink = true;
      hyperlinks = true;
      images = "kitty";
      trueColor = true;
    };

    images = {
      autoResize = true;
      blockImages = false;
    };

    compaction = {
      enabled = true;
      reserveTokens = 8192;
      keepRecentTokens = 16000;
    };

    retry = {
      enabled = true;
      maxRetries = 2;
      baseDelayMs = 1500;
      provider = {
        timeoutMs = 1800000;
        maxRetries = 0;
        maxRetryDelayMs = 45000;
      };
    };

    steeringMode = "one-at-a-time";
    followUpMode = "one-at-a-time";
    transport = "auto";
    httpIdleTimeoutMs = 300000;
    websocketConnectTimeoutMs = 15000;

    defaultTools = [
      "read"
      "bash"
      "edit"
      "write"
      "grep"
      "find"
      "ls"
    ];
    enableSkillCommands = true;
  };

  piModels = {
    providers = {
      ollama = {
        baseUrl = "http://127.0.0.1:11434/v1";
        api = "openai-completions";
        apiKey = "ollama-local-not-a-secret";
        compat = {
          supportsDeveloperRole = false;
          supportsReasoningEffort = false;
          supportsUsageInStreaming = false;
          supportsStore = false;
          maxTokensField = "max_tokens";
        };
        models = [
          (localModel {
            id = "llama3.2:3b";
            name = "Llama 3.2 3B (local quick)";
            maxTokens = 2048;
            temperature = 0.2;
          })
          (localModel {
            id = "qwen2.5:7b";
            name = "Qwen 2.5 7B (local general)";
            temperature = 0.25;
          })
          (localModel {
            id = "qwen2.5-coder:7b";
            name = "Qwen 2.5 Coder 7B (local code)";
            temperature = 0.12;
          })
          (localModel {
            id = "qwen2.5-coder:14b";
            name = "Qwen 2.5 Coder 14B (local code, large)";
            contextWindow = 16384;
            maxTokens = 8192;
            temperature = 0.10;
          })
          (localModel {
            id = "deepseek-r1:8b";
            name = "DeepSeek R1 8B (local reasoning)";
            contextWindow = 16384;
            maxTokens = 8192;
            temperature = 0.15;
          })
        ];
      };

      # Anthropic — API key read from ANTHROPIC_API_KEY env var at runtime.
      # Run `piauth` after exporting your key, or use `pi /login` inside the TUI.
      anthropic = {
        models = [
          (cloudModel {
            id = "claude-haiku-4-5-20251001";
            name = "Claude Haiku 4.5 (fast)";
            contextWindow = 200000;
            maxTokens = 8192;
            costInput = 0.80;
            costOutput = 4.00;
            costCacheRead = 0.08;
            costCacheWrite = 1.00;
          })
          (cloudModel {
            id = "claude-sonnet-4-6";
            name = "Claude Sonnet 4.6 (balanced)";
            contextWindow = 200000;
            maxTokens = 16000;
            reasoning = true;
            costInput = 3.00;
            costOutput = 15.00;
            costCacheRead = 0.30;
            costCacheWrite = 3.75;
          })
          (cloudModel {
            id = "claude-opus-4-7";
            name = "Claude Opus 4.7 (powerful)";
            contextWindow = 200000;
            maxTokens = 16000;
            reasoning = true;
            costInput = 15.00;
            costOutput = 75.00;
            costCacheRead = 1.50;
            costCacheWrite = 18.75;
          })
        ];
      };

      # OpenAI — API key read from OPENAI_API_KEY env var at runtime.
      openai = {
        models = [
          (cloudModel {
            id = "gpt-4o";
            name = "GPT-4o (general)";
            contextWindow = 128000;
            maxTokens = 16384;
            costInput = 2.50;
            costOutput = 10.00;
            costCacheRead = 1.25;
          })
          (cloudModel {
            id = "o4-mini";
            name = "o4-mini (reasoning)";
            contextWindow = 200000;
            maxTokens = 65536;
            reasoning = true;
            costInput = 1.10;
            costOutput = 4.40;
            costCacheRead = 0.275;
          })
        ];
      };
    };
  };

  piKeybindings = {
    "app.model.select" = "ctrl+l";
    "app.model.cycleForward" = "ctrl+p";
    "app.model.cycleBackward" = [
      "shift+ctrl+p"
      "alt+p"
    ];
    "app.session.tree" = "ctrl+shift+t";
    "app.session.resume" = "ctrl+shift+r";
    "app.thinking.cycle" = "shift+tab";
    "app.tools.expand" = "ctrl+o";
    "tui.input.newLine" = [
      "shift+enter"
      "ctrl+j"
    ];
    "tui.input.submit" = "enter";
    "tui.editor.historyPrevious" = "ctrl+up";
    "tui.editor.historyNext" = "ctrl+down";
    "tui.altScreen.search" = "ctrl+shift+f";
  };

  hackerBoxAgent = ''
    ---
    name: hacker-box
    description: Pull-up local-first operator for nixos-hacker-box.
    mode: primary
    color: "#00ffff"
    model: ollama/qwen2.5:7b
    thinking: low
    systemPrompt: append
    maxDepth: 4
    allowedAgents: [nix-scout, web-recon, service-doctor, dev-scout]
    permission:
      "*": allow
      bash:
        "sudo *": deny
        "doas *": deny
        "rm -rf *": deny
        "sops *": deny
        "make switch": deny
        "nixos-rebuild switch *": deny
    ---

    You are PI, the pull-up operator console for nixos-hacker-box.

    Work local-first. Inspect /etc/nixos, systemctl, journalctl,
    /run/current-system and local service endpoints before speculating.
    Keep answers compact — one paragraph or a short list, no padding.

    For system queries: use bash tools directly. For NixOS code: delegate
    to nix-scout. For web research: use ddgr, curl, jq, htmlq; delegate
    complex research to web-recon. For service failures: delegate to
    service-doctor. For code tasks: delegate to dev-scout.

    Never print secrets or credentials. On destructive actions: explain
    the safe path, don't execute.
  '';

  devScoutAgent = ''
    ---
    name: dev-scout
    description: Multi-agent code investigation and implementation specialist.
    mode: primary
    color: "#8b00ff"
    model: ollama/qwen2.5-coder:7b
    thinking: low
    systemPrompt: append
    maxDepth: 4
    allowedAgents: [nix-scout, web-recon]
    permission:
      "*": allow
      bash:
        "sudo *": deny
        "doas *": deny
        "rm -rf *": deny
        "sops *": deny
        "make switch": deny
        "nixos-rebuild switch *": deny
    ---

    You are DEV-SCOUT, a code investigation and implementation agent
    for nixos-hacker-box.

    Before editing any file: read it first. After writing Nix: run
    `make check`. Follow the conventions in CLAUDE.md exactly:
    - Module arg `_:` for no args (statix W10)
    - Group repeated top-level keys (statix W20)
    - English doc comment at the top of every module
    - Secrets never in the Nix store

    Delegate read-only investigation to nix-scout, external docs and
    package versions to web-recon. Decompose large tasks into subtasks
    and tackle them one file at a time.
  '';

  nixScoutAgent = ''
    ---
    name: nix-scout
    description: Read-only NixOS/Home Manager investigator.
    mode: subagent
    color: "#00ff88"
    model: ollama/qwen2.5-coder:7b
    thinking: low
    systemPrompt: append
    permission:
      "*": deny
      read: allow
      grep: allow
      find: allow
      ls: allow
      edit: deny
      write: deny
      bash:
        "*": allow
        "sudo *": deny
        "doas *": deny
        "rm -rf *": deny
        "sops *": deny
        "make switch": deny
        "nixos-rebuild switch *": deny
    ---

    Inspect this NixOS flake without editing. Focus on concrete file paths,
    module boundaries, option names, and compatibility with the conventions in
    AGENTS.md / CLAUDE.md.
  '';

  webReconAgent = ''
    ---
    name: web-recon
    description: Online research helper for primary sources and current facts.
    mode: subagent
    color: "#ffb000"
    model: ollama/qwen2.5:7b
    thinking: low
    systemPrompt: append
    permission:
      "*": deny
      read: allow
      edit: deny
      write: deny
      bash:
        "*": allow
        "sudo *": deny
        "doas *": deny
        "rm -rf *": deny
        "sops *": deny
        "make switch": deny
        "nixos-rebuild switch *": deny
    ---

    Research with verifiable URLs. Prefer official documentation, release
    notes, standards pages and primary repositories. Always report absolute
    dates for time-sensitive claims.
  '';

  serviceDoctorAgent = ''
    ---
    name: service-doctor
    description: Read-only systemd/log triage for local services.
    mode: subagent
    color: "#ff3355"
    model: ollama/qwen2.5:7b
    thinking: low
    systemPrompt: append
    permission:
      "*": deny
      read: allow
      grep: allow
      find: allow
      ls: allow
      edit: deny
      write: deny
      bash:
        "*": allow
        "sudo *": deny
        "doas *": deny
        "rm -rf *": deny
        "sops *": deny
        "make switch": deny
        "nixos-rebuild switch *": deny
    ---

    Diagnose local service health without changing state. Return the likely
    cause, concrete evidence, and the smallest safe next command.
  '';

  piWorkspace = pkgs.writeShellApplication {
    name = "hb-pi-workspace";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      tmux
    ];
    text = ''
      pi_bin="${piBin}/pi"
      mode="fresh"
      trap ':' INT QUIT

      cd /etc/nixos
      while true; do
        clear
        if [ ! -x "$pi_bin" ]; then
          printf '%s\n\n' \
            'PI CODING AGENT IS NOT INSTALLED YET' \
            'Run make switch, then this permanent workspace will recover automatically.'
          sleep 5
          continue
        fi

        args=(--agent hacker-box --name hb-cockpit)
        case "$mode" in
          continue) args+=(--continue) ;;
          resume) args+=(--resume) ;;
        esac

        status=0
        "$pi_bin" "''${args[@]}" || status=$?
        printf '\n\033[36mPI WORKSPACE\033[0m exited with status %s\n' "$status"
        printf '[r] restart  [c] continue last  [s] session picker  [d] docs  [q] shell window\n'
        action=""
        IFS= read -r -n 1 action || true
        printf '\n'

        case "$action" in
          c) mode="continue" ;;
          s) mode="resume" ;;
          d)
            [ -n "''${TMUX:-}" ] && tmux select-window -t hb:docs 2>/dev/null || true
            mode="continue"
            ;;
          q)
            [ -n "''${TMUX:-}" ] && tmux select-window -t hb:shell 2>/dev/null || true
            mode="continue"
            ;;
          *) mode="fresh" ;;
        esac
      done
    '';
  };
in
{
  home = {
    packages = [ piWorkspace ];
    sessionPath = [ piBin ];

    sessionVariables = {
      PI_SKIP_VERSION_CHECK = "1";
      EDITOR = "nvim";
      VISUAL = "nvim";
      PAGER = "less -R";
      MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    };

    file = {
      ".pi/agent/settings.json".text = builtins.toJSON piSettings;
      ".pi/agent/models.json".text = builtins.toJSON piModels;
      ".pi/agent/keybindings.json".text = builtins.toJSON piKeybindings;
      ".pi/agent/agents/hacker-box.md".text = hackerBoxAgent;
      ".pi/agent/agents/dev-scout.md".text = devScoutAgent;
      ".pi/agent/agents/nix-scout.md".text = nixScoutAgent;
      ".pi/agent/agents/web-recon.md".text = webReconAgent;
      ".pi/agent/agents/service-doctor.md".text = serviceDoctorAgent;
    };

    activation = {
      # Keep Pi and Claude Code on the same repository-level instructions when
      # the checkout has no AGENTS.md yet. Existing real files are preserved.
      pi-link-agents-md = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -f /etc/nixos/CLAUDE.md ] && [ ! -e /etc/nixos/AGENTS.md ]; then
          $DRY_RUN_CMD ln -sf CLAUDE.md /etc/nixos/AGENTS.md
        fi
      '';

      pi-install = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        export PATH="${pkgs.nodejs_22}/bin:$PATH"
        $DRY_RUN_CMD install -d "${piDir}"
        if [ ! -f "${piDir}/package.json" ]; then
          $DRY_RUN_CMD ${pkgs.nodejs_22}/bin/npm init -y \
            --prefix "${piDir}" >/dev/null
        fi
        $DRY_RUN_CMD ${pkgs.nodejs_22}/bin/npm install \
          --prefix "${piDir}" \
          --ignore-scripts --no-audit --no-fund --loglevel=error \
          @earendil-works/pi-coding-agent
      '';
    };
  };
}
