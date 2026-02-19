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
        pkgs = import nixpkgs { inherit system; };
      in
      {
        apps =
          let
            runner = self.nixosConfigurations.microvm.config.microvm.declaredRunner;
            mkApp = program: {
              type = "app";
              inherit program;
            };
            helmGenSchema = pkgs.writeShellScript "helm-gen-schema" ''
              ${pkgs.kubernetes-helmPlugins.helm-schema}/helm-schema/bin/schema \
                -f ./chart/values.yaml \
                -o ./chart/values.schema.json
            '';
            helmValidate = pkgs.writeShellScript "helm-validate" ''
              set -ex
              ${pkgs.kubernetes-helm}/bin/helm lint ./chart
              ${pkgs.kubernetes-helm}/bin/helm template test-release ./chart > /dev/null
            '';
          in
          rec {
            start = mkApp "${runner}/bin/microvm-run";
            default = start;
            stop = mkApp "${runner}/bin/microvm-shutdown";
            helmGenSchema = mkApp "${helmGenSchema}";
            validateHelm = mkApp "${helmValidate}";
          };
        packages.default = self.nixosConfigurations.microvm.config.system.build.toplevel;
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
