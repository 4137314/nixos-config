/*
  home/git.nix — Git configuration managed by Home Manager (25.11 layout).

  Identity
  --------
  User name and email are set from the user memory (mattia.fait@gmail.com).
  Adjust here if the identity should ever change; Nix will regenerate
  ~/.config/git/config on the next Home Manager activation.

  Diff / merge quality of life
  ----------------------------
  delta            Syntax-highlighted diff pager with side-by-side view.
  rerere           Remember conflict resolutions so recurring merges auto-apply.
  pull.rebase      Rebase-by-default policy — keeps history linear.
  push.autoSetupRemote  `git push` on a new branch creates the upstream ref.
  init.defaultBranch    New repos start on `main`, not `master`.

  Aliases (short, muscle-memory oriented)
  ---------------------------------------
  st  status -sb           lg  log --graph --oneline --all --decorate
  co  checkout             sw  switch
  ci  commit               ca  commit --amend --no-edit
  br  branch               d   diff (delta by default)
  ds  diff --staged        undo  reset --soft HEAD~1
*/
{ pkgs, ... }:
{
  programs = {
    git = {
      enable = true;
      package = pkgs.git;

      settings = {
        user = {
          name = "Mattia Fait";
          email = "mattia.fait@gmail.com";
        };

        alias = {
          st = "status -sb";
          co = "checkout";
          sw = "switch";
          ci = "commit";
          ca = "commit --amend --no-edit";
          br = "branch";
          d = "diff";
          ds = "diff --staged";
          lg = "log --graph --oneline --all --decorate";
          undo = "reset --soft HEAD~1";
          last = "log -1 HEAD --stat";
          unstage = "reset HEAD --";
        };

        init.defaultBranch = "main";
        pull.rebase = true;
        rebase.autoStash = true;
        rebase.autoSquash = true;
        rerere.enabled = true;
        push.autoSetupRemote = true;
        push.followTags = true;
        fetch.prune = true;
        diff.algorithm = "histogram";
        diff.colorMoved = "default";
        merge.conflictStyle = "zdiff3";
        column.ui = "auto";
        branch.sort = "-committerdate";
        tag.sort = "version:refname";
        help.autocorrect = 20;
        commit.verbose = true;
      };

      ignores = [
        # Editors
        ".vscode/"
        ".idea/"
        "*.swp"
        "*.swo"
        # OS
        ".DS_Store"
        "Thumbs.db"
        # Python
        "__pycache__/"
        "*.py[cod]"
        ".venv/"
        "venv/"
        # Node
        "node_modules/"
        # direnv / nix
        ".direnv/"
        ".envrc.local"
        "result"
        "result-*"
      ];
    };

    # `delta` pager for git — moved out of programs.git in HM 25.11.
    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true;
        line-numbers = true;
        side-by-side = true;
        syntax-theme = "Dracula";
      };
    };

    # GitHub CLI: shares auth with `git` operations via the credential helper.
    gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
        prompt = "enabled";
      };
    };

    # Lazygit: TUI wrapper — used from Neovim (<leader>gg) and directly.
    lazygit = {
      enable = true;
      settings.gui.showIcons = true;
    };
  };
}
