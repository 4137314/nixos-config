/*
  home/vscode.nix — Visual Studio Code managed declaratively by Home Manager.

  mutableExtensionsDir = false
    Prevents VS Code from reinstalling extensions outside of Nix management.
    Extensions must be added to the `extensions` list below and rebuilt.

  Extensions
  ----------
  anthropic.claude-code   Claude AI integration (chat, inline completions).
  jnoortheen.nix-ide      Nix language support backed by the nixd LSP server.

  Editor settings
  ---------------
  autoUpdate / autoCheckUpdates  Disabled — Nix manages versions.
  nix.serverPath                 Points to `nixd` from the system PATH.
  formatOnSave                   Enabled globally; per-language overrides apply.
  rulers                         Visual guide at 100 characters.
*/
{ pkgs, ... }:
{
  programs.vscode = {
    enable               = true;
    mutableExtensionsDir = false;

    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        anthropic.claude-code
        jnoortheen.nix-ide
      ];

      userSettings = {
        "extensions.autoUpdate"                    = false;
        "extensions.autoCheckUpdates"              = false;
        "nix.enableLanguageServer"                 = true;
        "nix.serverPath"                           = "nixd";
        "terminal.integrated.defaultProfile.linux" = "zsh";
        "files.autoSave"                           = "off";
        "editor.formatOnSave"                      = true;
        "editor.rulers"                            = [ 100 ];
      };
    };
  };
}
