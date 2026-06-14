# F5SPKVlan CR — external VLAN (trunk 1.1).
#
# Binds TMM trunk 1.1 to the ext-vlan name inside the TMM pod netns,
# announcing the SelfIP that was pre-assigned as a secondary IP on the
# external ENI (AWS) or equivalent host interface. The Nth NAD in the
# CNEInstance .spec.networkAttachments maps to trunk 1.N; external is
# always listed first (trunk 1.1).
#
# Source: awsbnkctl:internal/k8s/manifests/host-device/f5spkvlan.yaml.tmpl
# Rendered vars: InstanceNS, TmmExtSelfIP, TmmSelfIPPrefixLen
#
# This file uses Terraform templatefile() syntax (${var}).
apiVersion: k8s.f5net.com/v1
kind: F5SPKVlan
metadata:
  name: ext-vlan
  namespace: ${instance_namespace}
spec:
  name: ext-vlan
  interfaces:
    - "1.1"
  selfip_v4s:
    - "${tmm_ext_selfip}"
  prefixlen_v4: ${tmm_selfip_prefixlen}
  tag: 0
  auto_lasthop: AUTO_LASTHOP_ENABLED
