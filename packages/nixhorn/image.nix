{ pkgs, nixhorn }:
pkgs.dockerTools.buildImage {
  name = "ghcr.io/mschulte/nixhorn-webhook";
  tag = nixhorn.version;
  copyToRoot = pkgs.buildEnv {
    name = "image-root";
    paths = [ nixhorn ];
    pathsToLink = [ "/bin" ];
  };
  config.Entrypoint = [ "${nixhorn}/bin/nixhorn-webhook" ];
}
