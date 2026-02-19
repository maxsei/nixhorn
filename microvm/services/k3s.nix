{ pkgs, ... }:
{
  services.k3s.enable = true;

  environment.systemPackages = with pkgs; [
    yq-go
    kubectl
    k9s
  ];

  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
}
