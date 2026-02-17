{
  description = "NixOS in MicroVMs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixidy = {
      url = "github:arnarg/nixidy";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      microvm,
      nixidy,
    }:
    (flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (_final: _prev: {
              nixidy = nixidy.packages.${system};
            })
          ];
        };
      in
      {
        apps.default = {
          type = "app";
          program = "${self.nixosConfigurations.microvm.config.microvm.declaredRunner}/bin/microvm-run";
        };
      }
    ))
    // (flake-utils.lib.eachDefaultSystemPassThrough (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (_final: _prev: {
              nixidy = nixidy.packages.${system};
            })
          ];
        };
        nixidyEnvs = nixidy.lib.mkEnvs {
          inherit pkgs;
          envs.default.modules = [ ./manifests.nix ];
        };
      in
      {
        inherit nixidyEnvs;

        nixosConfigurations.microvm = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            ./microvm.nix
            {
              services.k3s.manifests.nixidy-manifests = {
                source = nixidyEnvs.default.declarativePackage;
                target = "nixidy-manifests";
              };
            }
          ];
        };
      }
    ));
}
