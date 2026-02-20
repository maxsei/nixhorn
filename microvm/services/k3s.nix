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

  services.k3s.manifests.nixidy-manifests = {
    source = pkgs.nixidyEnvs.default.declarativePackage;
    target = "nixidy-manifests";
  };

  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
}
