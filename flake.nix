{
  description = "NixOS module for Semaphore - Ansible/Terraform/OpenTofu UI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in {
      nixosModules = {
        default = import ./module.nix;
        semaphore = import ./module.nix;
      };

      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = self.packages.${system}.semaphore;
          semaphore = pkgs.callPackage ./package.nix { };
        }
      );

      overlays.default = final: prev: {
        semaphore = self.packages.${prev.system}.semaphore;
      };
    };
}
