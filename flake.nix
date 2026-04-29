{
  description = "NixOS Flake Configuration per Hacker Box";

  inputs = {
    # Usiamo la versione 23.11 come nel tuo file originale
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    # "nixos-hacker-box" deve corrispondere al networking.hostName che hai in configuration.nix
    nixosConfigurations.nixos-hacker-box = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
      ];
    };
  };
}
