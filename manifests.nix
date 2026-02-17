{ lib, ... }:
{
  nixidy.target.rootPath = "manifests";
  nixidy.target.repository = "";
  nixidy.target.branch = "";

  applications.longhorn = {
    namespace = "longhorn-system";
    createNamespace = true;

    helm.releases.longhorn = {
      # https://raw.githubusercontent.com/longhorn/charts/refs/heads/v1.11.x/charts/longhorn/values.yaml
      chart = lib.helm.downloadHelmChart {
        repo = "https://charts.longhorn.io";
        chart = "longhorn";
        version = "1.11.0";
        chartHash = "sha256-s1UBZTlU/AW6ZQmqN9wiQOA76uoWgCBGhenn9Hx3DCQ=";
      };

      values = {
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
    };
  };
}
