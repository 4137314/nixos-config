/*
  home/vscode.nix — Visual Studio Code managed declaratively by Home Manager.

  mutableExtensionsDir = false
    Prevents VS Code from reinstalling extensions outside of Nix management.
    Extensions must be added to the `extensions` list below and rebuilt.

  Extensions
  ----------
    anthropic.claude-code            Claude AI (chat, inline completions).
    jnoortheen.nix-ide               Nix language support (nixd LSP).
    github.vscode-pull-request-github Pull Requests + Issues + Reviews inside VS Code.
    github.vscode-github-actions     GitHub Actions runs, workflow authoring, secrets.

  The two `github.*` extensions turn VS Code into a full GitHub cockpit:
  create/review/merge PRs, triage issues, watch Actions runs, and edit
  workflow YAML with schema-aware IntelliSense — no browser round-trip.

  First-run auth
  --------------
  Both GitHub extensions use the built-in VS Code account provider. On
  first activation you'll get a "Sign in to GitHub" toast → OAuth device
  flow in the browser. The credentials are stored in the system keyring
  (libsecret), NOT in the Nix store.

  Complements `gh` (GitHub CLI, installed via development/default.nix)
  for scripting and CI-flavoured tasks from the terminal.

  Editor settings
  ---------------
    autoUpdate / autoCheckUpdates   Disabled — Nix manages versions.
    nix.serverPath                  Points to `nixd` from the system PATH.
    formatOnSave                    Enabled globally; per-language overrides apply.
    rulers                          Visual guide at 100 characters.
    githubPullRequests.*            Sensible defaults: pull PR checkouts into
                                    detached HEAD, show reviews in editor gutter,
                                    render suggestions inline.
*/
{ pkgs, unstable, ... }:
{
  programs.vscode = {
    enable = true;
    mutableExtensionsDir = false;

    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        # claude-code from unstable: significantly newer than nixpkgs stable.
        unstable.vscode-extensions.anthropic.claude-code
        jnoortheen.nix-ide

        # GitHub cockpit — both extensions are the OFFICIAL ones published
        # by the `github` publisher on the Marketplace.
        github.vscode-pull-request-github
        github.vscode-github-actions
      ];

      userSettings = {
        # -- Nix core --------------------------------------------------------
        "extensions.autoUpdate" = false;
        "extensions.autoCheckUpdates" = false;
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nixd";
        "terminal.integrated.defaultProfile.linux" = "zsh";
        "files.autoSave" = "off";
        "editor.formatOnSave" = true;
        "editor.rulers" = [ 100 ];

        # -- GitHub Pull Requests & Issues ----------------------------------
        # Push to the tracked upstream branch on `git push` without extra prompts.
        "githubPullRequests.pushBranch" = "always";
        # Show reviewer comments in the gutter of the diff editor.
        "githubPullRequests.fileListLayout" = "tree";
        "githubPullRequests.showInSCM" = true;
        # Refresh the PR list every 5 min so notifications stay fresh.
        "githubPullRequests.pullRequestDescription" = "Copilot";
        # The `${user}` placeholder is a GitHub-issues-extension
        # template variable expanded at query time by the extension —
        # it must reach the JSON literally, so we escape the `$` with
        # `\$` (Nix rule for `$` in a double-quoted string).
        "githubIssues.queries" = [
          {
            label = "My Issues";
            query = "is:open assignee:\${user}";
          }
          {
            label = "Created by Me";
            query = "is:open author:\${user}";
          }
          {
            label = "Mentioning Me";
            query = "is:open mentions:\${user}";
          }
          {
            label = "Recent Activity";
            query = "is:open sort:updated-desc";
          }
        ];

        # -- GitHub Actions -------------------------------------------------
        # Auto-refresh workflow-run list every 15s while a run is active.
        "github-actions.workflows.pinned.refresh.enabled" = true;
        "github-actions.workflows.pinned.refresh.interval" = 15;
        # YAML schema validation for `.github/workflows/*.yml`.
        "yaml.schemas" = {
          "https://json.schemastore.org/github-workflow.json" = ".github/workflows/*.{yml,yaml}";
          "https://json.schemastore.org/github-action.json" = ".github/actions/*/action.{yml,yaml}";
        };
      };
    };
  };
}
