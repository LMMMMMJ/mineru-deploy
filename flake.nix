{
  description = "MinerU Docker Deployment on NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  };

  outputs = { self, flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      
      imports = [
        ./nix/development.nix
        ./nix/packages.nix
      ];
      
      flake = {
        # NixOS module for MinerU service
        nixosModules.mineru = import ./mineru-service/module.nix;
      };
      
      perSystem = { system, config, pkgs, ... }: {
        formatter = pkgs.nixfmt-rfc-style or pkgs.nixfmt;
      };
    };
}

