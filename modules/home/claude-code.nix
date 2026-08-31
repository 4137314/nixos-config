/*
  home/claude-code.nix — Declarative Claude Code CLI user config.

  Manages the user-global ~/.claude/ files that are safe for Nix to own.
  Repo-level settings live under each project's .claude/ directory (e.g.
  /etc/nixos/.claude/settings.json is committed) and Claude Code merges
  them on top of these globals at runtime.

  Managed files
  -------------
    ~/.claude/settings.json           model, effort, statusLine, minimal allow
    ~/.claude/statusline-command.sh   bash script that renders the status bar

  Left unmanaged (Claude Code writes to them)
  -------------------------------------------
    ~/.claude/{sessions,projects,plugins,cache,file-history,tasks,backups}
    ~/.claude/{history.jsonl,.credentials.json,mcp-needs-auth-cache.json}

  If ~/.claude/settings.json already exists as a plain file on first
  activation, Home Manager renames it to settings.json.hm-backup
  (see `backupFileExtension = "hm-backup"` in flake.nix).

  Iterating on the statusline
  ---------------------------
  Edit modules/home/claude-code/statusline.sh, then `make switch`.
  jq and git are installed by home/packages.nix and Home Manager, so the
  script finds them on PATH.
*/
{ config, ... }:
let
  claudeDir = "${config.home.homeDirectory}/.claude";

  settings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";

    # Defaults for interactive sessions. Overridden per-repo via
    # /etc/nixos/.claude/settings.json when working inside this flake.
    model = "opus";
    effortLevel = "max";

    statusLine = {
      type = "command";
      command = "bash ${claudeDir}/statusline-command.sh";
    };

    # Cross-repo baseline permissions. Per-repo settings add project-specific
    # entries (Makefile targets, nix commands, module paths, etc.).
    permissions = {
      allow = [
        "Bash(gh:*)"
        "Read(//proc/**)"
        "Read(//run/current-system/**)"
      ];
    };
  };
in
{
  home.file = {
    ".claude/settings.json".text = builtins.toJSON settings;
    ".claude/statusline-command.sh" = {
      source = ./claude-code/statusline.sh;
      executable = true;
    };
  };
}
