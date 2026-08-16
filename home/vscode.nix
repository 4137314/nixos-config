{ pkgs, ... }:

# ─────────────────────────────────────────────────────────────────────────────
# VSCode: estensioni e impostazioni gestite da Nix.
# mutableExtensionsDir = false impedisce reinstallazioni dal marketplace.
# ─────────────────────────────────────────────────────────────────────────────
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
