{ ... }:
{
  imports = [
    ./configuration.nix
    ./hardware.nix
    ./services/openiscsi.nix
    ./services/k3s.nix
    ./services/nixhorn-loader.nix
  ];
}
