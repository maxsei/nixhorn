{ ... }:
{
  defaultSettings = {
    defaultReplicaCount = 1;
    defaultDataPath = "/var/lib/longhorn";
  };
  persistence = {
    defaultClass = true;
    defaultClassReplicaCount = 1;
  };
  service.ui.type = "ClusterIP";
  longhornManager = {
    resources = {
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
}
