{ pkgs, ... }:
{
  services.k3s.enable = true;

  systemd.services.k3s = rec {
    after = [ "iscsid.service" ];
    requires = after;
  };

  environment.systemPackages = with pkgs; [
    yq-go
    kubectl
    k9s
  ];

  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
}
