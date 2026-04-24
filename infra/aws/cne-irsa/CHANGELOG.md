# Changelog

All notable changes to this module will be documented in this file.

## [0.1.0] - 2026-04-23

### Added — Initial module

IRSA + `allow-ec2-vip` IAM policy for the F5 CNE controller's ServiceAccount.
Required by the kernel-mode TMM blueprint shipped in `infra/aws/high-performance-nodes`
2.3.0 (commit 0b90406 on `fix/engine-module-source-of-truth`).

- Creates `<cluster>-allow-ec2-vip` IAM policy with the four EC2 actions
  per F5 Doc 3 page 30 (`AssignPrivateIpAddresses`, `UnassignPrivateIpAddresses`,
  `DescribeInstances`, `DescribeNetworkInterfaces`)
- Creates `<cluster>-cne-controller-vip` IAM role with OIDC trust to the
  CNE controller's ServiceAccount in the `f5-operator` namespace
- Annotates the SA with `eks.amazonaws.com/role-arn` (waits up to 300s for
  FLO to create it) and rollout-restarts the controller Deployment so the
  EKS pod-identity webhook injects credentials

### Pending validation

End-to-end VIP-through-controller-push hasn't been validated on a fresh
cluster yet — aws-syd-test (where the kernel-mode TMM was hand-validated at
L2/L3) is locked as a live demo. First fresh deploy from this module should
confirm: SA annotation lands, controller pod has `AWS_ROLE_ARN` env set,
selfips/VIPs auto-appear as secondary IPs on the dedicated ENIs, and a same-VPC
client can curl the Gateway VIP without manual IP/route patching inside the
TMM pod.
