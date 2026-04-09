# Ubuntu kind remote bootstrap

This module is a bounded first slice for blank-host bootstrap.

It now treats `infra/ubuntu/kind` as a **remote SSH bootstrap module**, not a local helper. Given SSH access to an Ubuntu host, it:

1. connects to the remote host over SSH
2. verifies or installs `docker`, `kind`, and `kubectl`
3. creates a kind cluster on the **remote host**
4. copies the generated kubeconfig back to the runner as an artifact

## What this slice does

- makes `ssh_host`, `ssh_user`, and `ssh_private_key_path` real inputs
- fails early if remote bootstrap inputs are missing
- installs prerequisite packages needed to bootstrap Docker on Ubuntu
- installs `kind` and `kubectl` if absent
- creates the cluster remotely using the requested worker count and Kubernetes version
- returns a truthful kubeconfig artifact path and endpoint derived from that kubeconfig

## What this slice does not do yet

- prove BNK-on-kind compatibility
- install Multus, SR-IOV, hugepages, or other BNK-specific prerequisites
- harden package installation for every Ubuntu variant or locked-down environment
- rewrite the kubeconfig server endpoint for off-host API reachability

The copied kubeconfig is truthful to the remote kind cluster, but the embedded API server endpoint may still point at the remote host's local/container-network address. A later slice should normalize or broker API access for Forge runtime consumption.

## Required inputs

- `ssh_host` — remote Ubuntu host/IP
- `ssh_private_key_path` — private key path on the runner

## Optional inputs

- `ssh_user` — defaults to `ubuntu`
- `ssh_timeout` — defaults to `10m`
- `cluster_name` — defaults to `bnk-dev`
- `worker_nodes` — defaults to `2`
- `kubernetes_version` — defaults to `1.29.2`
- `kind_version` — defaults to `v0.23.0`
- `kubectl_version` — defaults to `v1.29.2`

## Outputs

- `kubeconfig_path` — local path to the copied kubeconfig artifact
- `cluster_name` — cluster name
- `cluster_endpoint` — endpoint read from the copied kubeconfig
- `remote_kubeconfig_path` — kubeconfig path on the remote host
- `remote_host` — remote host used for bootstrap

## Notes

- This module currently installs `docker` via `get.docker.com` when Docker is absent.
- It assumes passwordless `sudo` is available when the SSH user is not root.
- Destroy deletes the kind cluster on the remote host and removes the local copied kubeconfig artifact.
