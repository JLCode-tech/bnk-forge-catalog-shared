# F5SPKVlan CR — internal VLAN (trunk 1.2, dual-interface only).
#
# Applied only when the cluster uses a dual-interface data-plane pattern
# (external + internal TMM interfaces). Single-interface (external-only)
# patterns skip this CR.
#
# Source: awsbnkctl:internal/k8s/manifests/host-device/f5spkvlan.yaml.tmpl
# Rendered vars: InstanceNS, TmmIntSelfIP, TmmSelfIPPrefixLen
#
# This file uses Terraform templatefile() syntax (${var}).
apiVersion: k8s.f5net.com/v1
kind: F5SPKVlan
metadata:
  name: int-vlan
  namespace: ${instance_namespace}
spec:
  name: int-vlan
  internal: true
  interfaces:
    - "1.2"
  selfip_v4s:
    - "${tmm_int_selfip}"
  prefixlen_v4: ${tmm_selfip_prefixlen}
  tag: 0
  auto_lasthop: AUTO_LASTHOP_ENABLED
