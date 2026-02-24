{ pkgs, nixhorn-webhook }:
(pkgs.dockerTools.buildImage {
  name = "ghcr.io/maxsei/nixhorn-webhook";
  tag = nixhorn-webhook.version;
  copyToRoot = pkgs.buildEnv {
    name = "image-root";
    paths = [ nixhorn-webhook ];
    pathsToLink = [ "/bin" ];
  };
  config.Entrypoint = [ "${nixhorn-webhook}/bin/nixhorn-webhook" ];
}) // {
  passthru.version = nixhorn-webhook.version;
}
