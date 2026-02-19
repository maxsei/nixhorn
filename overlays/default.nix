final: prev: {
  nixhorn = final.callPackage ../packages/nixhorn { };
  nixhorn-image = final.callPackage ../packages/nixhorn/image.nix {
    nixhorn = final.nixhorn;
  };
}
