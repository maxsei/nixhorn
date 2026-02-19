{ ... }:
{
  applications.nixhorn-webhook = {
    namespace = "longhorn-system";
    helm.releases.nixhorn-webhook = {
      chart = ../../chart;
    };
  };
}
