{ pkgs, config, ... }:
{
  services.openiscsi = {
    enable = true;
    name = "${config.networking.hostName}-initiatorhost";
  };

  environment.systemPackages = with pkgs; [
    nfs-utils
    openiscsi
  ];
}
