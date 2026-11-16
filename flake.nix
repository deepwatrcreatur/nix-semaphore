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

      # INVARIANT: module users get the same package the updater bumps.
      checks.x86_64-linux.module-default-package =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          eval = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              self.nixosModules.default
              {
                boot.isContainer = true;
                services.semaphore.enable = true;
                system.stateVersion = "25.05";
              }
            ];
          };
          actual = eval.config.services.semaphore.package;
          expected = self.packages.x86_64-linux.semaphore;
        in
        assert actual.outPath == expected.outPath;
        pkgs.runCommand "module-default-package" { } ''
          echo "module default package: ${actual.name}" > $out
        '';

      overlays.default = final: prev: {
        semaphore = self.packages.${prev.system}.semaphore;
      };
    };
}
