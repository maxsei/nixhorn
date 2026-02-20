final: prev: {
  nixhorn = final.callPackage ../packages/nixhorn { };
  nixhorn-image = final.callPackage ../packages/nixhorn/image.nix {
    nixhorn = final.nixhorn;
  };
  nixhorn-chart = final.callPackage ../packages/nixhorn/chart { };
  helm-schema = final.callPackage ../packages/helm-schema.nix { };
}
