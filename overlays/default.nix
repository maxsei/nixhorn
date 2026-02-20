final: prev: {
  nixhorn-webhook = final.callPackage ../packages/nixhorn-webhook { };
  nixhorn-webhook-image = final.callPackage ../packages/nixhorn-webhook/image.nix {
    nixhorn-webhook = final.nixhorn-webhook;
  };
  nixhorn-webhook-chart = final.callPackage ../packages/nixhorn-webhook/chart {
    nixhorn-webhook-image = final.nixhorn-webhook-image;
  };
  helm-schema = final.callPackage ../packages/helm-schema.nix { };
}
