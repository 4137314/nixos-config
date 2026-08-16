/*
  flake.nix — Entry point for the NixOS flake configuration.

  Inputs
  ------
  nixpkgs          Stable channel (25.11) — base system and most packages.
  nixpkgs-unstable Unstable channel — bleeding-edge packages (Neovim, etc.).
  home-manager     User environment management, pinned to the stable release.

  The `unstable` package set is instantiated once here and forwarded to every
  Home Manager module via `extraSpecialArgs`, avoiding repeated imports.
*/
{
  description = "NixOS configuration — nixos-hacker-box (Workstation + NAS)";

  inputs = {
    nixpkgs.url          = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }@inputs:
  let
    system = "x86_64-linux";

    # Instantiated once; forwarded to Home Manager modules via extraSpecialArgs.
    unstable = import inputs.nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };
  in {

    nixosConfigurations.nixos-hacker-box = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs    = true;
            useUserPackages  = true;
            extraSpecialArgs = { inherit inputs unstable; };
            users.main       = import ./home.nix;
          };
        }
      ];
    };

  };
}
