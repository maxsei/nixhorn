{ lib, pkgs, ... }:
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
  };

  applications.patch-longhorn-manager-adm-ctl = {
    namespace = "longhorn-system";
    helm.releases.patch-longhorn-manager-adm-ctl = {
      chart = ./chart;
    };
  };
}
