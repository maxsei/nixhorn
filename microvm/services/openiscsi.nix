{ pkgs, ... }:
{
  services.openiscsi = {
    enable = true;
    name = "microvm-initiatorhost";
  };

  environment.systemPackages = with pkgs; [
    nfs-utils
    openiscsi
  ];
}
