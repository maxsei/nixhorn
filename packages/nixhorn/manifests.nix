{ pkgs, ... }:
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
      # {
      #   name = "longhorn";
      #   releaseName = "longhorn";
      #   namespace = "longhorn-system";
      #   valuesInline = longhorn-values;
      # }
    ];
    # components = [ "./patches" ];
  };
in
pkgs.runCommand "nixhorn-manifests"
  {
    nativeBuildInputs = with pkgs; [
      kubernetes-helm
      kustomize
    ];
  }
  (''
    cp ${kustomization} kustomization.yaml
    cp -r ${longhorn-chart} longhorn
    cp -r ${../../chart} nixhorn-webhook
    cp -r ${../../patches} patches
    kustomize build --enable-helm . > $out
  '')
