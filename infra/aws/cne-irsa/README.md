# infra/aws/cne-irsa

IRSA + IAM policy for the F5 CNE controller's ServiceAccount, so it can call
`ec2:AssignPrivateIpAddresses` to attach BNK Gateway VIPs and F5SPKVlan
selfips as secondary IPs on the dedicated SR-IOV / host-device ENIs.

**Required** when `bnk/cneinstance.tmm_data_plane_mode = "kernel"` (the
default as of 2026-04-23). Without this:

- `F5SPKVlan` CRs reach `Programmed=True` but the selfips never get attached
  to the ENIs at the AWS layer
- `Gateway` resources reach `Programmed=True` but the VIPs are unreachable
  from same-VPC clients (AWS VPC routing has no entry mapping the VIP to the
  dedicated ENI's MAC)

Per F5 Doc 3 (AWS Cloud Multi-AZ Network Architecture Deployment Guide),
pages 28-31.

## What this module does

1. Creates IAM policy `<cluster_name>-allow-ec2-vip` with the four EC2
   actions Doc 3 page 30 calls out:
   - `ec2:AssignPrivateIpAddresses`
   - `ec2:UnassignPrivateIpAddresses`
   - `ec2:DescribeInstances`
   - `ec2:DescribeNetworkInterfaces`
2. Creates IAM role `<cluster_name>-cne-controller-vip` with a trust policy
   bound to the cluster's IAM OIDC provider for the CNE controller's
   `ServiceAccount` (`f5-operator/f5-cne-controller-default-f5-cne-controller-serviceaccount`)
3. Attaches the policy (plus any extra managed policies via
   `extra_managed_policy_arns`)
4. Annotates the CNE controller SA with `eks.amazonaws.com/role-arn`,
   waiting up to `wait_for_sa_timeout_seconds` (default 300s) for FLO to
   create it
5. Rollout-restarts the CNE controller Deployment so the EKS pod-identity
   webhook injects the IRSA env vars (`AWS_ROLE_ARN`,
   `AWS_WEB_IDENTITY_TOKEN_FILE`) into a fresh pod

## Inputs

See `variables.tf`. The module is auto-wired in BNK-Forge; for standalone
use the only required inputs are:

- `cluster_name` — EKS cluster
- `oidc_provider_arn`, `oidc_provider_url` — from `infra/aws/eks` outputs
- `forge_kubeconfig_content` — a kubeconfig YAML for the kubectl annotate step

## Outputs

- `role_arn` — ARN of the IRSA role
- `policy_arn` — ARN of the IAM policy
- `annotated_serviceaccount` — `namespace/name` of the SA that was annotated
- `ready` — boolean, true after the annotate + rollout-restart completes

## Wiring order

```
infra/aws/eks
    ↓
bnk/flo                            # FLO operator running
    ↓
bnk/cneinstance                    # CNEInstance CR applied → FLO creates SA
    ↓
infra/aws/cne-irsa                 # this module — annotates SA + restarts controller
    ↓
bnk/bnk-vlans, bnk/gateway, ...    # gate on cne-irsa.ready before applying
```

## Standalone use

```hcl
module "cne_irsa" {
  source = "git::https://github.com/.../bnk-forge-modules.git//infra/aws/cne-irsa?ref=2.2-rev.27"

  cluster_name             = module.eks.cluster_name
  oidc_provider_arn        = module.eks.oidc_provider_arn
  oidc_provider_url        = module.eks.oidc_provider_url
  forge_kubeconfig_content = file("~/.kube/config")
  cneinstance_ready        = module.cneinstance.ready
}
```

## Verifying it worked

After this module applies:

```bash
# SA is annotated
kubectl -n f5-operator get sa f5-cne-controller-default-f5-cne-controller-serviceaccount \
  -o jsonpath='{.metadata.annotations}' | jq

# Controller pod has IRSA env injected
kubectl -n f5-operator exec deploy/f5-cne-controller -- env | grep AWS_

# Apply a Gateway and confirm the VIP appears as a secondary IP on the
# dedicated external ENI within a few seconds
kubectl get gateway -A
aws ec2 describe-network-interfaces \
  --filters "Name=tag:ENIType,Values=external-dpdk" \
  --query 'NetworkInterfaces[*].PrivateIpAddresses[*].PrivateIpAddress'
```

## See also

- F5 Doc 3 — AWS Cloud Multi-AZ Network Architecture Deployment Guide
  (pages 28-31 cover trust profile + IAM policy)
- `bnk/cneinstance/README.md` — kernel-mode TMM env vars + Multus annotation
- `infra/aws/high-performance-nodes/CHANGELOG.md` — `[2.3.0]` for the
  kernel-mode default rollout
