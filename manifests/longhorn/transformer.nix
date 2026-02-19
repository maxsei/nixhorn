{ lib, ... }:
let
  wait-for-nixhorn-webhook = {
    name = "wait-for-nixhorn-webhook";
    image = "bitnami/kubectl:latest";
    command = [
      "sh"
      "-c"
      ''
        echo "Waiting for MutatingWebhookConfiguration..."
        until kubectl get mutatingwebhookconfiguration nixhorn-webhook 2>/dev/null; do
          sleep 2
        done

        echo "Waiting for webhook deployment to be available..."
        kubectl wait deployment nixhorn-webhook \
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
          wait-for-nixhorn-webhook
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
          wait-for-nixhorn-webhook
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
)
