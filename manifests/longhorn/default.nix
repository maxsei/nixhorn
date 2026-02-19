{ lib, ... }:
{
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

      values = import ./app.nix { inherit lib; };

      transformer = import ./transformer.nix { inherit lib; };
    };
  };
}
