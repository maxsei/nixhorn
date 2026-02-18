{ lib, pkgs, ... }:
let
  # Base64 encoded CA certificate for the admission webhook
  # This is the tlcrt file that's baked into the container image
  caCert = builtins.readFile ./certs/tlcrt;
  # Kubernetes requires the PEM certificate to be base64-encoded (without newlines)
  caBundle = builtins.readFile (
    pkgs.runCommand "ca-bundle" { } ''
      base64 -w 0 ${./certs/tlcrt} > $out
    ''
  );
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
      };
      transformer =
        let
          wait-for-patch-longhorn-manager-adm-ctl = {
            name = "wait-for-patch-longhorn-manager-adm-ctl";
            image = "bitnami/kubectl:latest";
            command = [
              "sh"
              "-c"
              ''
                echo "Waiting for MutatingWebhookConfiguration..."
                until kubectl get mutatingwebhookconfiguration patch-longhorn-manager-adm-ctl 2>/dev/null; do
                  sleep 2
                done

                echo "Waiting for webhook deployment to be available..."
                kubectl wait deployment patch-longhorn-manager-adm-ctl \
                  -n longhorn-system \
                  --for=condition=available \
                  --timeout=300s
                echo "Webhook deployment is available"
              ''
            ];
            resources = {
              requests = {
                cpu = "10m";
                memory = "32Mi";
              };
              limits = {
                cpu = "50m";
                memory = "64Mi";
              };
            };
          };
          patchContainerWithNixPath =
            c:
            let
              nix-path = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/run/wrappers/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin";
              env-path-parted = builtins.partition (v: v.name == "PATH") (c.env or [ ]);
              path = (builtins.elemAt (env-path-parted.right ++ [ { } ]) 0).value or "";
              new-path = path + (if path == "" then "" else ":") + nix-path;
              new-env = env-path-parted.wrong ++ [
                {
                  name = "PATH";
                  value = new-path;
                }
              ];
            in
            c // { env = new-env; };

          patchDaemonSetLonghornManager =
            mf:
            if
              (lib.attrByPath [ "kind" ] null mf) == "DaemonSet"
              && (lib.attrByPath [ "metadata" "name" ] null mf) == "longhorn-manager"
            then
              lib.recursiveUpdate mf {
                spec.template.spec.initContainers = [
                  wait-for-patch-longhorn-manager-adm-ctl
                ];
                spec.template.spec.containers = map patchContainerWithNixPath mf.spec.template.spec.containers;
              }
            else
              mf;
          patchDeploymentLonghornDriverDeployer =
            mf:
            if
              (lib.attrByPath [ "kind" ] null mf) == "Deployment"
              && (lib.attrByPath [ "metadata" "name" ] null mf) == "longhorn-driver-deployer"
            then
              lib.recursiveUpdate mf {
                spec.template.spec.initContainers = [
                  wait-for-patch-longhorn-manager-adm-ctl
                ];
              }
            else
              mf;
        in
        map (
          mf:
          lib.pipe mf [
            patchDaemonSetLonghornManager
            patchDeploymentLonghornDriverDeployer
          ]
        );
    };

    resources =
      let
        labels = {
          "app.kubernetes.io/name" = "patch-longhorn-manager-adm-ctl";
          "app.kubernetes.io/component" = "admission-webhook";
        };
      in
      {
        deployments.patch-longhorn-manager-adm-ctl.spec = {
          replicas = 1;
          selector.matchLabels = labels;
          template = {
            metadata.labels = labels;
            spec = {
              containers.webhook = {
                image = "docker.io/microvm/patch-longhorn-manager-adm-ctl:0.1.0";
                imagePullPolicy = "Never";
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

        services.patch-longhorn-manager-adm-ctl.spec = {
          selector = labels;
          ports.https = {
            port = 443;
            targetPort = 8443;
            protocol = "TCP";
          };
        };

        "admissionregistration.k8s.io".v1.MutatingWebhookConfiguration.patch-longhorn-manager-adm-ctl = {
          metadata.name = "patch-longhorn-manager-adm-ctl";
          webhooks = [
            {
              name = "patch-longhorn-manager-adm-ctl.longhorn-system.svc.cluster.local";
              clientConfig = {
                service = {
                  namespace = "longhorn-system";
                  name = "patch-longhorn-manager-adm-ctl";
                  path = "/mutate";
                };
                caBundle = caBundle;
              };
              rules = [
                {
                  operations = [ "CREATE" ];
                  apiGroups = [ "" ];
                  apiVersions = [ "v1" ];
                  resources = [ "pods" ];
                  scope = "Namespaced";
                }
              ];
              namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "longhorn-system";
              admissionReviewVersions = [ "v1" ];
              sideEffects = "None";
              timeoutSeconds = 10;
              failurePolicy = "Ignore"; # Don't block pod creation if webhook fails
            }
          ];
        };
      };
  };
}
