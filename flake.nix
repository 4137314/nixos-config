{
  description = "NixOS Flake Configuration per Hacker Box";

inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    
    # URL esplicito per evitare il 404 dell'API di GitHub
    neovim-nightly-flake.url = "github:nix-community/neovim-nightly-flake?ref=master";
    
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = { self, nixpkgs, neovim-nightly-flake, home-manager, hyprland, ... }@inputs: {
    nixosConfigurations.nixos-hacker-box = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.main = import ./home.nix;
        }
      ];
    };
  };
}
