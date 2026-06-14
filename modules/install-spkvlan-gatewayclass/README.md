# install-spkvlan-gatewayclass

Cloud-agnostic primitive: apply `F5SPKVlan` and `GatewayClass` custom resources for the BNK host-device data-plane pattern.

## Why this matters

Even when a `CNEInstance` reaches `Programmed`, TMM cannot pass traffic without:

1. **F5SPKVlan CRs** — bind TMM trunks (1.1 = external, 1.2 = internal) to named VLANs inside the TMM pod network namespace, announcing the SelfIP addresses assigned to the external (and optionally internal) host interfaces. Without SelfIPs, TMM has no data-plane identity on those interfaces.
2. **GatewayClass CR** — registers the BNK `cne-controller` as a Gateway API implementation. Operator-facing `Gateway` CRs must reference `spec.gatewayClassName` matching this CR's name. Without GatewayClass, operator Gateways are orphaned and no listeners/pools are programmed in TMM.

## Source reference

| Artifact | awsbnkctl source |
|---|---|
| F5SPKVlan YAML shape | `internal/k8s/manifests/host-device/f5spkvlan.yaml.tmpl` |
| GatewayClass YAML shape | `internal/k8s/manifests/host-device/gatewayclass.yaml.tmpl` |
| Render logic | `internal/k8s/render/render.go` (`RenderF5SPKVlan`, `RenderGatewayClass`, `F5SPKVlanVars`, `GatewayClassVars`) |
| Apply phase | `internal/aws/phases/phase23b_spkvlan_gatewayclass.go` (`Phase23bSPKVlanGatewayClass`) |

## Deploy order

```
... → cneinstall → [License CR] → install-spkvlan-gatewayclass → [operator Gateway CRs / traffic validation]
```

Per awsbnkctl Phase 23b: this runs **after** the License CR (Phase 23) and **before** CWC heal (Phase 24). FLO's `crd-installer` Job installs both the `F5SPKVlan` CRD and the `GatewayClass` CRD only after `CNEInstance` reaches `Reconciled`. This module waits for both CRDs before applying either CR (otherwise, GatewayClass apply races the RESTMapper cache — see awsbnkctl audit docs/audits/2026-05-24-h4-rev-live-cycle Cycle-2 Finding #1).

## SelfIP inputs (cloud-specific)

The SelfIP addresses (`tmm_ext_selfip`, `tmm_int_selfip`) are **cloud-specific** and must be supplied by the per-cloud wrapper module. This module does not discover them.

**On AWS (EKS):** the per-cloud wrapper (`eks-cluster-install-spkvlan-gatewayclass`) sources them from the secondary IP assignment in the ENI-attach phase (awsbnkctl Phase 17 assigns these via `ec2:AssignPrivateIpAddresses`). Typically: the last IP in the data-plane subnet /24 — e.g., `10.0.10.240` for subnet `10.0.10.0/24`.

**On other clouds:** the equivalent secondary private IP on the external (and internal) data-plane interface.

## Interfaces

The external interface maps to trunk `1.1` and the internal interface to trunk `1.2`. This matches the `networkAttachments` order in `CNEInstance.spec`: the Nth attachment → trunk 1.N. External is always listed first.

## Inputs

### Required

| Name | Description |
|---|---|
| `cluster_name` | Logical cluster name. GatewayClass CR is named `<cluster_name>-gatewayclass`. |
| `tmm_ext_selfip` | SelfIP for the external VLAN (trunk 1.1). Cloud-specific secondary IP (e.g. AWS ENI secondary IP). |

### Optional

| Name | Default | Description |
|---|---|---|
| `instance_namespace` | `f5-cne-system` | Namespace for CNEInstance and F5SPKVlan CRs. Must match `cneinstall`. |
| `tmm_int_selfip` | `""` | SelfIP for internal VLAN (trunk 1.2). Required when `has_internal_interface=true`. |
| `tmm_selfip_prefixlen` | `24` | IPv4 prefix length for both SelfIPs. Must match data-plane subnet prefix. |
| `has_internal_interface` | `false` | Apply `int-vlan` F5SPKVlan CR (dual-interface TMM pattern). |
| `gatewayclass_name` | `""` | Override GatewayClass CR name. Default: `<cluster_name>-gatewayclass`. |
| `crd_wait_timeout` | `600s` | `kubectl wait` timeout for F5SPKVlan + GatewayClass CRDs. FLO installs these after CNEInstance reconciles (may take 10+ min on cold cluster). |

## Outputs

| Output | Used by |
|---|---|
| `gatewayclass_name` | Operator `Gateway` CRs (must set `spec.gatewayClassName`) |
| `f5spkvlan_ext_applied` | Diagnostics |
| `spkvlan_gatewayclass_ready` | **Gate output** — downstream traffic validation steps |

## Destroy behaviour

Deletes `F5SPKVlan/ext-vlan`, `F5SPKVlan/int-vlan` (if dual-interface), and the `GatewayClass` CR with `--ignore-not-found`. The CRDs themselves are NOT deleted (owned by FLO; let FLO lifecycle them with the CNEInstance).

## Vendoring into per-cloud catalogs

Per-cloud catalogs vendor this as (e.g.) `modules/eks-cluster-install-spkvlan-gatewayclass`. The wrapper module adds:
- Discovery of `tmm_ext_selfip` / `tmm_int_selfip` from the secondary-ENI assignment phase outputs.
- Optionally: an additional per-node kubelet capacity check for `hugepages-2Mi` if not already gated by the hugepages module.

## Maturity

`alpha` — CR shapes and apply logic extracted from awsbnkctl Phase 23b (proven in production EKS deploys).
