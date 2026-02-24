{ pkgs, ... }:
let
  nixhorn-manifests =
    let
      # https://raw.githubusercontent.com/longhorn/charts/refs/tags/longhorn-1.11.0/charts/longhorn/values.yaml
      longhorn-chart = builtins.fetchTarball {
        url = "https://github.com/longhorn/charts/releases/download/longhorn-1.11.0/longhorn-1.11.0.tgz";
        sha256 = "sha256:090cfxyg9rz9hm32100nxbm3pq204bf3gah9cnx0bz2l75jh2mdk";
      };
      longhorn-values = {
        defaultSettings = {
          defaultReplicaCount = 1;
          defaultDataPath = "/var/lib/longhorn";
        };
        persistence = {
          defaultClass = true;
          defaultClassReplicaCount = 1;
        };
        service.ui.type = "ClusterIP";
        longhornManager.resources = {
          requests = {
            cpu = "100m";
            memory = "128Mi";
          };
          limits = {
            cpu = "200m";
            memory = "256Mi";
          };
        };
      };

      kustomization = pkgs.writers.writeYAML "kustomization.yaml" {
        apiVersion = "kustomize.config.k8s.io/v1beta1";
        kind = "Kustomization";
        helmGlobals.chartHome = ".";
        helmCharts = [
          {
            name = "nixhorn-webhook";
            releaseName = "nixhorn-webhook";
            namespace = "longhorn-system";
          }
          {
            name = "longhorn";
            releaseName = "longhorn";
            namespace = "longhorn-system";
            valuesInline = longhorn-values;
          }
        ];
        components = [ "./manifests" ];
      };
    in
    pkgs.runCommand "nixhorn-manifests"
      {
        nativeBuildInputs = with pkgs; [
          kubernetes-helm
          kustomize
        ];
      }
      ''
        cp ${kustomization} kustomization.yaml
        cp -r ${longhorn-chart} longhorn
        cp -r ${pkgs.nixhorn-webhook-chart} nixhorn-webhook
        cp -r ${./manifests} manifests
        kustomize build --enable-helm . > $out
      '';
in
{
  services.nixhorn-loader.enable = true;
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
      "01-manifests.yaml" = "${nixhorn-manifests}";
    };
  };
}
