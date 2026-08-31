/*
  flake.nix — Entry point for the NixOS flake configuration.

  Inputs
  ------
  nixpkgs          Stable channel (25.11) — base system and most packages.
  nixpkgs-unstable Unstable channel — current desktop tools and editors.
  hyprland        Hyprland 0.55.4 — compositor pinned to a tested release.
  hyprexpo        Maintained workspace overview, ABI-aligned with Hyprland.
  home-manager     User environment management, pinned to the stable release.
  sops-nix         Encrypted-at-rest secrets management (age / GPG backed).
  git-hooks        Pre-commit hooks (formatter + lint + smoke tests).
  treefmt-nix      Multi-language formatter driver (Nix / Lua / Shell / …).
  nix-index-db     Pre-built nixpkgs file index powering `comma`.

  Outputs
  -------
  nixosConfigurations.nixos-hacker-box   The live system.
  devShells.<system>.default             `nix develop` — repo hacking shell
                                         (nixfmt, statix, deadnix, nixd, sops,
                                         age, ssh-to-age, plus pre-commit hooks
                                         installed automatically).
  formatter.<system>                     `nix fmt` — treefmt over all languages.
  checks.<system>.pre-commit             `nix flake check` — runs the hooks.

  The `unstable` package set is instantiated once here and forwarded to every
  Home Manager module via `extraSpecialArgs`, avoiding repeated imports.
*/
{
  description = "NixOS configuration — nixos-hacker-box (Workstation + NAS)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Keep the compositor and its C++ plugin on the exact same ABI. The
    # maintained HyprExpo fork also tracks this Hyprland release explicitly.
    hyprland.url = "github:hyprwm/Hyprland/v0.55.4";
    hyprexpo = {
      url = "github:sandwichfarm/hyprexpo";
      inputs.hyprland.follows = "hyprland";
    };
    # The package flake on `master` already targets Hyprland 0.56. Its
    # v0.55.4 source tag is the compatible implementation for our pin.
    hyprexpo-source = {
      url = "github:sandwichfarm/hyprexpo/e76761b268a0ee1747d41e21355fa315797a9bfd";
      flake = false;
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      sops-nix,
      git-hooks,
      treefmt-nix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # Instantiated once; forwarded to Home Manager modules via extraSpecialArgs.
      unstable = import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      # ------------------------------------------------------------------
      # treefmt — one formatter to rule them all.
      # ------------------------------------------------------------------
      treefmtEval = treefmt-nix.lib.evalModule pkgs {
        projectRootFile = "flake.nix";
        programs = {
          nixfmt.enable = true;
          stylua.enable = true;
          shfmt.enable = true;
          prettier = {
            enable = true;
            includes = [
              "*.md"
              "*.yaml"
              "*.yml"
              "*.json"
            ];
          };
        };
        settings.formatter.shfmt.options = [
          "-i"
          "2"
          "-ci"
        ];
      };

      # ------------------------------------------------------------------
      # pre-commit hooks — installed by `nix develop`, run on every commit.
      # ------------------------------------------------------------------
      preCommitCheck = git-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          treefmt = {
            enable = true;
            package = treefmtEval.config.build.wrapper;
          };
          statix = {
            enable = true;
            settings.ignore = [ "hardware-configuration.nix" ];
          };
          deadnix = {
            enable = true;
            settings.edit = false;
            excludes = [ "hardware-configuration\\.nix" ];
          };
          nil.enable = true;
          check-yaml.enable = true;
          check-added-large-files.enable = true;
          check-merge-conflicts.enable = true;
          check-executables-have-shebangs.enable = true;
          detect-private-keys.enable = true;
        };
      };
    in
    {
      nixosConfigurations.nixos-hacker-box = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          sops-nix.nixosModules.sops
          inputs.nix-index-database.nixosModules.nix-index
          home-manager.nixosModules.home-manager
          {
            programs.nix-index-database.comma.enable = true;

            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs unstable; };
              users.main = import ./modules/home;
              # If HM finds a plain (non-symlink) file where it wants to
              # place its own, rename it with this suffix instead of
              # bailing out. Prevents the "would be clobbered" failure
              # of `home-manager-main.service` on the first switch when
              # existing dotfiles live in ~/.config already.
              backupFileExtension = "hm-backup";
            };
          }
        ];
      };

      # `nix develop` — flake authoring shell. Installs pre-commit hooks
      # automatically via shellHook.
      devShells.${system}.default = pkgs.mkShell {
        name = "hacker-box-devshell";
        inherit (preCommitCheck) shellHook;
        packages =
          (with pkgs; [
            # Nix quality
            nixfmt-rfc-style
            statix
            deadnix
            nixd
            nil

            # Secrets tooling
            sops
            age
            ssh-to-age

            # General
            git
            gnumake
            jq

            # AI-agent tooling — CLIs and MCP server runtimes.
            # nodejs_22 exposes `npx` for @modelcontextprotocol/server-*
            # (filesystem, http), uv exposes `uvx` for mcp-server-git.
            nodejs_22
            uv
          ])
          ++ [
            treefmtEval.config.build.wrapper
            # Coding-agent CLIs pinned to unstable to track upstream releases
            # closely (matches the "unstable for editors/tools" pattern used
            # for Neovim). See modules/home/packages.nix for the HM install.
            unstable.claude-code
            unstable.codex
          ];
      };

      # `nix fmt` — treefmt (multi-language).
      formatter.${system} = treefmtEval.config.build.wrapper;

      # `nix flake check` — runs treefmt + statix + deadnix + nil + hooks.
      checks.${system} = {
        pre-commit = preCommitCheck;
        formatting = treefmtEval.config.build.check ./.;
      };
    };
}
