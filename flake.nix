{
  description = "NixOS in MicroVMs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      microvm,
    }:
    let
      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ (import ./overlays/default.nix) ];
        };
    in
    (flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = mkPkgs system;
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
              temp="$(mktemp -d)"
              trap 'rm -rf "$temp"' EXIT
              PWD_OLD="$(pwd)"
              cp -r "$PWD_OLD/manifests/chart" "$temp"
              cd "$temp/chart"
              ${pkgs.helm-schema}/bin/helm-schema
              cp ./values.schema.json "$PWD_OLD/manifests/chart"
            '';
            helmValidate = pkgs.writeShellScript "helm-validate" ''
              set -ex
              ${pkgs.kubernetes-helm}/bin/helm lint ./manifests/chart
              ${pkgs.kubernetes-helm}/bin/helm template test-release ./manifests/chart > /dev/null
            '';
          in
          {
            start = mkApp "${runner}/bin/microvm-run";
            stop = mkApp "${runner}/bin/microvm-shutdown";
            helmGenSchema = mkApp "${helmGenSchema}";
            helmValidate = mkApp "${helmValidate}";
          };
        packages = {
          microvm = self.nixosConfigurations.microvm.config.system.build.toplevel;
          nixhorn = pkgs.nixhorn;
          nixhorn-image = pkgs.nixhorn-image;
          nixhorn-manifests = pkgs.nixhorn-manifests;
        };
      }
    ))
    // (flake-utils.lib.eachDefaultSystemPassThrough (
      system:
      let
        pkgs = mkPkgs system;
      in
      {
        nixosConfigurations.microvm = pkgs.nixos {
          imports = [
            microvm.nixosModules.microvm
            ./microvm
          ];
        };
      }
    ));
}
