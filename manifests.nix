{ lib, ... }:
let
  # Base64 encoded CA certificate for the admission webhook
  # This is the tlcrt file that's baked into the container image
  caCert = builtins.readFile ./certs/tlcrt;
  caBundle = builtins.replaceStrings ["\n"] [""] caCert;
in
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

    resources = let
      labels = {
        "app.kubernetes.io/name" = "patch-longhorn-manager-adm-ctl";
        "app.kubernetes.io/component" = "admission-webhook";
      };
    in {
      deployments.patch-longhorn-manager-adm-ctl.spec = {
        replicas = 1;
        selector.matchLabels = labels;
        template = {
          metadata.labels = labels;
          spec = {
            containers.webhook = {
              # image = "localhost/patch-longhorn-manager-adm-ctl:0.1.0";
              image = "docker.io/microvm/patch-longhorn-manager-adm-ctl:0.1.0";
              imagePullPolicy = "Never"; # Image is loaded directly into containerd
              ports.https = {
                containerPort = 8443;
                protocol = "TCP";
              };
              livenessProbe = {
                httpGet = {
                  path = "/health";
                  port = 8443;
                  scheme = "HTTPS";
                };
                initialDelaySeconds = 10;
                periodSeconds = 10;
              };
              readinessProbe = {
                httpGet = {
                  path = "/health";
                  port = 8443;
                  scheme = "HTTPS";
                };
                initialDelaySeconds = 5;
                periodSeconds = 5;
              };
              resources = {
                requests = {
                  cpu = "50m";
                  memory = "64Mi";
                };
                limits = {
                  cpu = "100m";
                  memory = "128Mi";
                };
              };
            };
          };
        };
      };

      # Service to expose the webhook
      services.patch-longhorn-manager-adm-ctl.spec = {
        selector = labels;
        ports.https = {
          port = 443;
          targetPort = 8443;
          protocol = "TCP";
        };
      };

      # MutatingWebhookConfiguration to register the webhook with Kubernetes
      "admissionregistration.k8s.io".v1.MutatingWebhookConfiguration.patch-longhorn-manager-adm-ctl = {
        metadata.name = "patch-longhorn-manager-adm-ctl";
        webhooks = [{
          name = "patch-longhorn-manager-adm-ctl.longhorn-system.svc.cluster.local";
          clientConfig = {
            service = {
              namespace = "longhorn-system";
              name = "patch-longhorn-manager-adm-ctl";
              path = "/mutate";
            };
            caBundle = caBundle;
          };
          rules = [{
            operations = ["CREATE"];
            apiGroups = [""];
            apiVersions = ["v1"];
            resources = ["pods"];
            scope = "Namespaced";
          }];
          namespaceSelector = {
            matchLabels = {
              "kubernetes.io/metadata.name" = "longhorn-system";
            };
          };
          admissionReviewVersions = ["v1"];
          sideEffects = "None";
          timeoutSeconds = 10;
          failurePolicy = "Ignore"; # Don't block pod creation if webhook fails
        }];
      };
    };
  };
}
