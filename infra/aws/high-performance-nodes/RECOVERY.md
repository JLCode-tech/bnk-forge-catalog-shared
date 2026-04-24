# HP-node recovery — retrofit the "dedicated internal SR-IOV ENI" fix onto a live cluster

Use this runbook when you have a PoC cluster deployed from an older version of
this module (pre-dual-ENI script) and you can't tear down / redeploy.

## What's wrong on an affected node

Every HP node has **three** ENIs, but device index 1 is **not** the dedicated
internal SR-IOV ENI it should be — it's a VPC-CNI-created secondary ENI
sitting in the *primary* subnet, consuming PCI slot `0000:00:06.0` that the
SR-IOV device plugin expects to be the F5 internal VF.

Symptom: TMM's external VIP still answers for a while (via the correct
external ENI at device 2), but internal-side traffic (TMM → pod backends via
the internal SR-IOV VF) silently uses the VPC-CNI ENI. The F5SPKVlan
self-IPs end up on an ENI that VPC CNI has already filled with pod warm
IPs, leading to `PrivateIpAddressLimitExceeded` when forge or another
process tries to register new secondaries.

## Target end state

- device 0: primary ENI (node OS) — stays
- device 1: **dedicated internal SR-IOV ENI**, no_manage tag, in `*private-internal-<AZ>*` subnet
- device 2: **dedicated external SR-IOV ENI**, no_manage tag, in `*private-external-<AZ>*` subnet
- VPC CNI confined to device 0 via `aws-node-hp` DS (`MAX_ENI=1, WARM_ENI_TARGET=0`)
- SR-IOV device plugin config unchanged: internal=`0000:00:06.0`, external=`0000:00:07.0`

## Recovery strategy — "new internal at device 3, re-point SR-IOV"

Reattaching at device 1 requires draining pod IPs off the VPC-CNI ENI, which
means evicting pods that hold those IPs. On a live PoC that's disruptive.

The lower-risk path: **attach a new dedicated internal ENI at the next free
device index (typically 3) and re-point the SR-IOV device plugin's
`internal_netdevice` PCI address to the new slot**. The VPC-CNI ENI at
device 1 keeps serving its existing pod IPs; we just take the internal
SR-IOV path away from it.

### Mapping: device index → PCI slot on c5n.4xlarge / m5n / r5n

```
device 0 → 0000:00:05.0   (primary)
device 1 → 0000:00:06.0   (classic internal SR-IOV slot — stays stuck with VPC CNI in the broken state)
device 2 → 0000:00:07.0   (external SR-IOV — already correct)
device 3 → 0000:00:08.0   (unused — target for the new internal SR-IOV)
device 4 → 0000:00:09.0
...
```

### Step-by-step

All commands assume `$NODE` = name of the affected HP node (e.g.
`ip-10-0-21-136.ap-southeast-2.compute.internal`), `$INSTANCE` = its EC2
instance id, and that you run them from a host that can reach both the
cluster and AWS EC2 API (e.g. the jumphost + `aws-cli`).

1. **Find the node's VPC, AZ, and an available `*private-internal*` subnet in the same AZ.**

    ```sh
    INSTANCE=$(aws ec2 describe-instances --filters \
      "Name=private-dns-name,Values=$NODE" \
      --query 'Reservations[].Instances[0].[InstanceId,VpcId,Placement.AvailabilityZone]' \
      --output text)
    read -r INSTANCE_ID VPC_ID AZ <<<"$INSTANCE"

    INTERNAL_SUBNET=$(aws ec2 describe-subnets \
      --filters "Name=vpc-id,Values=$VPC_ID" \
                "Name=availability-zone,Values=$AZ" \
                "Name=tag:Name,Values=*private-internal*" \
      --query 'Subnets[0].SubnetId' --output text)

    CLUSTER_SG=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
      --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId' --output text)
    ```

2. **Create the dedicated internal ENI with the correct tags, attach at device 3.**

    ```sh
    ENI_ID=$(aws ec2 create-network-interface \
      --subnet-id $INTERNAL_SUBNET \
      --groups $CLUSTER_SG \
      --description "Internal SR-IOV ENI for HP node $INSTANCE_ID (recovery)" \
      --tag-specifications \
        "ResourceType=network-interface,Tags=[{Key=Name,Value=$INSTANCE_ID-internal-dpdk},{Key=node.k8s.amazonaws.com/no_manage,Value=true},{Key=ENIType,Value=internal-dpdk}]" \
      --query 'NetworkInterface.NetworkInterfaceId' --output text)

    aws ec2 attach-network-interface \
      --network-interface-id $ENI_ID \
      --instance-id $INSTANCE_ID \
      --device-index 3
    ```

3. **Re-point the SR-IOV device plugin's `internal_netdevice` PCI slot** from
   `0000:00:06.0` to `0000:00:08.0`:

    ```sh
    kubectl edit cm -n kube-system sriovdp-config
    # change:
    #   "pciAddresses": ["0000:00:06.0"]     ← old (device 1)
    # to:
    #   "pciAddresses": ["0000:00:08.0"]     ← new (device 3)
    # under resourceName: internal_netdevice
    ```

4. **Restart the SR-IOV device plugin pods** on each affected node so they
   rediscover the new PCI mapping and re-publish the
   `intel.com/internal_netdevice` (or vendor-equivalent) allocatable:

    ```sh
    kubectl delete pod -n kube-system -l app=sriov-device-plugin --field-selector spec.nodeName=$NODE
    ```

5. **Re-apply the F5SPKVlan CR** for the internal VLAN to force TMM to pick
   up the new VF. Do NOT delete the TMM pod — the F5SPKVlan controller
   pushes the new binding via gRPC when the CR is touched:

    ```sh
    kubectl annotate f5-spk-vlans.k8s.f5net.com internal -n f5-operator recovery-ts=$(date +%s) --overwrite
    ```

6. **Repeat steps 1-5 on every affected HP node**, then verify:

    ```sh
    # Internal ENI attached at device 3 (recovery) or device 1 (green-field)
    aws ec2 describe-instances --instance-ids $INSTANCE_ID \
      --query 'Reservations[].Instances[].NetworkInterfaces[].[Attachment.DeviceIndex,SubnetId,PrivateIpAddress,TagSet[?Key==`ENIType`].Value|[0]]' \
      --output text | sort -n

    # F5SPKVlan CRs programmed
    kubectl get f5-spk-vlans.k8s.f5net.com -n f5-operator \
      -o jsonpath='{range .items[*]}{.metadata.name}  programmed={.status.conditions[?(@.type=="Programmed")].status}{"\n"}{end}'
    ```

### What about VPC CNI on the recovered nodes?

The VPC-CNI secondary ENI at device 1 is still there and will keep serving
its existing pod IPs. That's fine. The important thing is the SR-IOV plugin
no longer *points* at it, so F5 DPDK and VPC CNI don't collide.

For **new HP nodes** (or if you eventually drain-and-replace the existing
ones), the module's updated `aws-node-hp` DS + `MAX_ENI=1` constraint
prevents VPC CNI from ever adding the device-1 secondary in the first
place — those nodes come up clean with the classic topology.

### When NOT to use this runbook

- If you can afford a drain-and-replace, it's simpler — just roll the
  nodegroup. Fresh nodes come up correctly under the updated module.
- If you're running with a mix of HP and non-HP nodes that share the
  default `aws-node` DS config — apply the anti-affinity patch first
  (see main.tf `null_resource.exclude_default_aws_node_from_hp`).
