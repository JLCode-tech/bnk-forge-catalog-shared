# Changelog

All notable changes to this module will be documented in this file.

## [2.2.0] - 2026-04-23

### Fixed — Dedicated internal SR-IOV ENI (was missing)

**Root cause (discovered on aws-syd-test):** the `eni-attachment-manager`
script only created the **external** SR-IOV ENI at device index 2. The
internal SR-IOV slot (PCI `0000:00:06.0`, device index 1) was left for
AWS VPC CNI to claim — which it promptly did on node boot, filling it with
pod warm IPs. Net effect: F5SPKVlan self-IPs for the internal VLAN ended
up targeting a VPC-CNI-managed ENI that was already at its AWS secondary-IP
cap, so TMM's internal-side traffic had no proper ENI binding and
`ec2:AssignPrivateIpAddresses` calls for new self-IPs / VIPs failed with
`PrivateIpAddressLimitExceeded`.

**Fix (two pieces):**

1. **`scripts/eni_attachment_manager.py`** — now creates **both** the
   internal and external SR-IOV ENIs. Internal attaches at device index 1
   in a `*private-internal-<AZ>*` subnet; external at device 2 in
   `*private-external-<AZ>*` (unchanged). Both tagged
   `node.k8s.amazonaws.com/no_manage=true` + `ENIType=internal-dpdk` /
   `external-dpdk`. Idempotent — re-runs skip types that already exist.
   Refuses to proceed if the target device index is already in use and
   logs which ENI is squatting (recovery guidance in `RECOVERY.md`).

2. **`manifests/aws-node-hp-daemonset.yaml` + terraform wiring** — a
   dedicated VPC-CNI DaemonSet scoped to HP nodes
   (`nodeSelector: node-type=high-performance`) with `MAX_ENI=1` and
   `WARM_ENI_TARGET=0`. The default `kube-system/aws-node` DS is patched
   with anti-affinity to **exclude** HP nodes (via
   `null_resource.exclude_default_aws_node_from_hp`), so each node-type
   runs exactly one aws-node variant. Result: VPC CNI on HP nodes uses
   only the primary ENI (30 IPs on c5n.4xlarge — plenty for a
   TMM-class workload), leaving device indices 1 and 2 reserved for
   the F5 SR-IOV ENIs.

**New variables:**
- `vpc_cni_image` (default: `amazon-k8s-cni:v1.18.5`) — image ref for the
  aws-node-hp DS
- `vpc_cni_image_tag` (default: `v1.18.5`)
- `kubeconfig_path` (default: `~/.kube/config`) — used by the anti-affinity
  patch local-exec
- `hugepages_2mb_count` (default: `1024`) — runtime 2MB hugepage count
  applied by the new `hugepages-setup` init container

**Known-gotcha note on `no_manage` + kubelet:** tagging an ENI
`node.k8s.amazonaws.com/no_manage=true` makes VPC CNI skip it, but
kubelet's `--max-pods` is derived from the instance-type's ENI/IP
capacity. When MAX_ENI is constrained to 1, `--max-pods` should be set to
the per-ENI IP count (e.g. 30 on c5n.4xlarge) — this is already handled
in the node userdata (`compact_userdata.sh`), but worth verifying if the
instance type changes.

### Added — Hugepages init container on `eni-attachment-manager` DS

Runtime 2MB hugepages allocation (Layer 2 of the three-layer hugepages
strategy from v2.1.0) now lives in a `hugepages-setup` init container on
the `eni-attachment-manager` DaemonSet. Self-healing — runs on every DS
(re)start, writes `/sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages`
to the desired value. Layers 1 (GRUB drop-in) and 3 (systemd service)
stay in node userdata since they only matter at boot.

### Added — `RECOVERY.md`

Surgical runbook for retrofitting the dedicated-internal-ENI fix onto a
live PoC cluster without draining / replacing nodes.

## [2.1.0] - 2026-02-10

### Fixed — Bulletproof Deployment (Lessons from Live Cluster)

These fixes address two root causes discovered on aws-sydney-bnk-demo-cluster that
caused TMM to be stuck in Pending state on first deploy:

#### 1. EKS AMI GRUB Hugepages Persistence
**Root cause**: EKS AL2 AMI bootstrap regenerates `/boot/grub2/grub.cfg` AFTER userdata
runs, overriding `sed` modifications to `/etc/default/grub`. Hugepages params were lost.

**Fix**: Three-layer hugepages allocation in `compact_userdata.sh`:
- **Layer 1**: GRUB drop-in config (`/etc/default/grub.d/99-dpdk-hugepages.cfg`) — survives
  EKS bootstrap regeneration
- **Layer 2**: Runtime sysfs allocation — hugepages available immediately without reboot
- **Layer 3**: `dpdk-hugepages.service` systemd unit — ensures hugepages on every boot
