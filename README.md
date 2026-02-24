# Nixhorn

A solution for running Longhorn on NixOS-based Kubernetes clusters. Nixhorn combines kustomize manifests and a mutating admission webhook to fix PATH environment variable compatibility issues.

## The Problem

Longhorn uses `nsenter` in privileged containers to execute host binaries like `iscsiadm`. On NixOS, this fails because:

1. Longhorn containers inherit an FHS-like PATH from their environment
2. NixOS binaries are in `/nix/store/*` and `/run/current-system/sw/bin`, not standard FHS paths
3. Longhorn manages container creation directly, preventing PATH configuration through standard Kubernetes methods

See: [longhorn/longhorn#2166](https://github.com/longhorn/longhorn/issues/2166)

## Solution

Nixhorn uses a two-part approach:

**1. Mutating Admission Webhook** - Automatically patches all Longhorn pod environments with a NixOS-compatible PATH:
```
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/run/wrappers/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin
```

**2. Kustomize Patches** - Ensures proper initialization and provides direct PATH patches for pre-existing longhorn resources:
- `wait-for-nixhorn-webhook.yaml` - Init containers that wait for webhook availability
- `patch-longhorn-manager-path.yaml` - Direct PATH patches for longhorn-manager DaemonSet

## Development

### Local Testing

```bash
# Start MicroVM with K3s and Longhorn
nix run .#start

# Stop MicroVM
nix run .#stop
```
