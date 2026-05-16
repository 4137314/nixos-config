{
  description = "NixOS Flake Configuration per Hacker Box";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    # Aggiungiamo il canale unstable ufficiale di NixOS
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, hyprland, ... }@inputs: {
    nixosConfigurations.nixos-hacker-box = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit inputs; }; # Passa gli inputs (incluso l'unstable) a home.nix
          home-manager.users.main = import ./home.nix;
        }
      ];
    };
  };
}
