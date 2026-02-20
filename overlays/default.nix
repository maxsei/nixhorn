final: prev: {
  nixhorn = final.callPackage ../packages/nixhorn { };
  nixhorn-image = final.callPackage ../packages/nixhorn/image.nix {
    nixhorn = final.nixhorn;
  };
  nixhorn-chart = final.callPackage ../packages/nixhorn/chart { };
  nixhorn-manifests = final.callPackage ../packages/nixhorn/manifests.nix { };
  helm-schema = final.callPackage ../packages/helm-schema.nix { };
}
