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

  services.k3s.manifests.nixhorn = {
    target = "nixhorn"; # must be directory
    source = pkgs.linkFarm "k3s-manifests-nixhorn" {
      "00-namespaces.yaml" = pkgs.writers.writeYAML "longhorn-system-namespace.yaml" {
        apiVersion = "v1";
        kind = "Namespace";
        metadata = rec {
          name = "longhorn-system";
          labels.name = name;
        };
      };
      "01-manifests.yaml" = "${pkgs.nixhorn-manifests}";
    };
  };
}
