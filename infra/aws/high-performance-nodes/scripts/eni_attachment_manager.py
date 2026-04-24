#!/usr/bin/env python3
"""
ENI Attachment Manager for EKS High-Performance Nodes

Creates and attaches TWO dedicated SR-IOV ENIs required for F5 TMM:
  - Internal SR-IOV ENI  → at device index 1 (PCI 0000:00:06.0) in a
    *private-internal-<AZ>* subnet
  - External SR-IOV ENI  → at device index 2 (PCI 0000:00:07.0) in a
    *private-external-<AZ>* subnet

Both ENIs are tagged ``node.k8s.amazonaws.com/no_manage=true`` so the AWS
VPC CNI leaves them alone. The complementary constraint (VPC CNI on HP
nodes uses only the primary ENI) lives in the main.tf via a dedicated
aws-node DaemonSet scoped with ``nodeSelector: node-type=high-performance``
and ``MAX_ENI=1, WARM_ENI_TARGET=0``.

Idempotent: safe to re-run. Detects already-attached F5 SR-IOV ENIs by
the ``ENIType`` tag and skips creation if present.

Known AWS gotcha with ``no_manage``: kubelet's ``--max-pods`` is
calculated from ``MAX_ENI × IPs-per-ENI``. When MAX_ENI is constrained
to 1 on HP nodes, kubelet --max-pods must be set accordingly (handled
by the node's userdata / kubelet-extra-args, not here).
"""

import logging
import os
import subprocess
import time
from typing import Dict, List, Optional, Tuple

import boto3
import requests

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Mapping: device index → (subnet name pattern, ENIType tag, PCI slot the
# SR-IOV device plugin expects). Order of this list = attach order; device
# index 1 MUST be claimed before VPC CNI adds its own secondary, which is
# why MAX_ENI=1 on aws-node (HP nodes) is a hard prerequisite.
F5_SRIOV_ENIS: List[Tuple[int, str, str, str]] = [
    # device_index, subnet_pattern, ENIType, pci_slot_for_sriovdp
    (1, "*private-internal*", "internal-dpdk", "0000:00:06.0"),
    (2, "*private-external*", "external-dpdk", "0000:00:07.0"),
]


class ENIAttachmentManager:
    def __init__(self):
        self.ec2_client = boto3.client("ec2")
        self.region = os.environ.get("AWS_DEFAULT_REGION", "ap-southeast-2")
        self.instance_id = self._get_instance_id()
        self.security_groups = [
            sg for sg in os.environ.get("SECURITY_GROUP_IDS", "").split(",") if sg
        ]

    def _get_instance_id(self) -> str:
        """Get instance ID from IMDSv2."""
        try:
            token_response = requests.put(
                "http://169.254.169.254/latest/api/token",
                headers={"X-aws-ec2-metadata-token-ttl-seconds": "21600"},
                timeout=5,
            )
            token = token_response.text
            response = requests.get(
                "http://169.254.169.254/latest/meta-data/instance-id",
                headers={"X-aws-ec2-metadata-token": token},
                timeout=5,
            )
            return response.text
        except Exception as e:
            logger.error(f"Error getting instance ID: {e}")
            return ""

    def _get_instance_info(self) -> Dict:
        """Get instance AZ / VPC / primary subnet."""
        try:
            response = self.ec2_client.describe_instances(InstanceIds=[self.instance_id])
            instance = response["Reservations"][0]["Instances"][0]
            return {
                "az": instance["Placement"]["AvailabilityZone"],
                "subnet_id": instance["SubnetId"],
                "vpc_id": instance["VpcId"],
            }
        except Exception as e:
            logger.error(f"Error getting instance info: {e}")
            return {}

    def _find_subnet(self, vpc_id: str, az: str, name_pattern: str) -> Optional[str]:
        """Find the first subnet in ``vpc_id`` in ``az`` whose Name tag matches the pattern."""
        try:
            response = self.ec2_client.describe_subnets(
                Filters=[
                    {"Name": "vpc-id", "Values": [vpc_id]},
                    {"Name": "availability-zone", "Values": [az]},
                    {"Name": "tag:Name", "Values": [name_pattern]},
                ]
            )
            if response["Subnets"]:
                return response["Subnets"][0]["SubnetId"]
            return None
        except Exception as e:
            logger.error(f"Error finding subnet for pattern {name_pattern}: {e}")
            return None

    def _get_existing_enis(self) -> List[Dict]:
        """Get existing ENIs attached to this instance."""
        try:
            response = self.ec2_client.describe_network_interfaces(
                Filters=[{"Name": "attachment.instance-id", "Values": [self.instance_id]}]
            )
            return response["NetworkInterfaces"]
        except Exception as e:
            logger.error(f"Error getting existing ENIs: {e}")
            return []

    def _has_f5_eni_of_type(self, existing_enis: List[Dict], eni_type: str) -> bool:
        """Return True if an ENI of this ``ENIType`` is already attached (idempotency)."""
        for eni in existing_enis:
            tags = {t["Key"]: t["Value"] for t in eni.get("TagSet", [])}
            if tags.get("ENIType") == eni_type:
                logger.info(
                    f"ENI {eni['NetworkInterfaceId']} of type {eni_type} "
                    f"already attached at device {eni.get('Attachment', {}).get('DeviceIndex')}"
                )
                return True
        return False

    def _device_index_in_use(self, existing_enis: List[Dict], device_index: int) -> bool:
        """Return True if some ENI is already attached at this device index."""
        for eni in existing_enis:
            if eni.get("Attachment", {}).get("DeviceIndex") == device_index:
                return True
        return False

    def _wait_for_eni_status(self, eni_id: str, status: str, timeout: int = 20) -> bool:
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                response = self.ec2_client.describe_network_interfaces(
                    NetworkInterfaceIds=[eni_id]
                )
                if response["NetworkInterfaces"]:
                    current_status = response["NetworkInterfaces"][0]["Status"]
                    if current_status == status:
                        return True
            except Exception as e:
                logger.warning(f"Error checking ENI status: {e}")
            time.sleep(1)
        logger.warning(f"Timeout waiting for ENI {eni_id} to become {status}")
        return False

    def _wait_for_interface_attached(self, device_index: int, timeout: int = 30) -> bool:
        expected = f"eth{device_index}"
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                result = subprocess.run(["ip", "link", "show"], capture_output=True, text=True)
                if expected in result.stdout:
                    logger.info(f"Interface {expected} appeared")
                    return True
            except Exception as e:
                logger.warning(f"Error checking interface: {e}")
            time.sleep(1)
        logger.warning(f"Timeout waiting for interface {expected}")
        return False

    def _create_and_attach_eni(
        self, subnet_id: str, device_index: int, eni_type: str
    ) -> bool:
        """Create an ENI in ``subnet_id`` and attach at ``device_index``."""
        try:
            logger.info(f"Creating {eni_type} ENI in subnet {subnet_id}")
            create_response = self.ec2_client.create_network_interface(
                SubnetId=subnet_id,
                Groups=self.security_groups,
                Description=f"{eni_type.title()} ENI for HP node {self.instance_id}",
                TagSpecifications=[
                    {
                        "ResourceType": "network-interface",
                        "Tags": [
                            {"Key": "Name", "Value": f"{self.instance_id}-{eni_type}"},
                            # Tells AWS VPC CNI: hands off.
                            {"Key": "node.k8s.amazonaws.com/no_manage", "Value": "true"},
                            {"Key": "ENIType", "Value": eni_type},
                        ],
                    }
                ],
            )
            eni_id = create_response["NetworkInterface"]["NetworkInterfaceId"]
            logger.info(f"Created ENI {eni_id} ({eni_type})")

            if not self._wait_for_eni_status(eni_id, "available"):
                logger.warning(f"ENI {eni_id} did not become available — attempting attach anyway")

            logger.info(f"Attaching ENI {eni_id} to {self.instance_id} at device {device_index}")
            self.ec2_client.attach_network_interface(
                NetworkInterfaceId=eni_id,
                InstanceId=self.instance_id,
                DeviceIndex=device_index,
            )
            logger.info(f"Attached {eni_type} ENI {eni_id} at device {device_index}")

            if not self._wait_for_interface_attached(device_index):
                logger.warning(f"Interface eth{device_index} did not appear in OS")

            return True
        except Exception as e:
            logger.error(f"Error creating/attaching {eni_type} ENI: {e}")
            return False

    def setup_additional_enis(self) -> bool:
        """
        Ensure both internal and external SR-IOV ENIs are attached at the
        expected device indices. Idempotent.
        """
        logger.info("Starting ENI attachment process")
        instance_info = self._get_instance_info()
        if not instance_info:
            logger.error("Could not get instance information")
            return False

        logger.info(f"Instance in AZ: {instance_info['az']}, VPC: {instance_info['vpc_id']}")

        overall_ok = True
        for device_index, subnet_pattern, eni_type, pci_slot in F5_SRIOV_ENIS:
            existing = self._get_existing_enis()

            # Idempotency: if an ENI of this type is already there, skip
            if self._has_f5_eni_of_type(existing, eni_type):
                continue

            # If the target device index is already in use (e.g. VPC CNI
            # grabbed it before us), bail with a specific error — the
            # operator must recover (see RECOVERY.md in this module).
            if self._device_index_in_use(existing, device_index):
                taken_by = next(
                    (
                        e["NetworkInterfaceId"]
                        for e in existing
                        if e.get("Attachment", {}).get("DeviceIndex") == device_index
                    ),
                    "<unknown>",
                )
                logger.error(
                    f"device index {device_index} already in use by {taken_by} — "
                    f"expected it free for {eni_type} SR-IOV ENI (PCI {pci_slot}). "
                    f"VPC CNI likely added a secondary here; ensure MAX_ENI=1 "
                    f"and WARM_ENI_TARGET=0 are set on the aws-node DaemonSet "
                    f"for this node (see the hp-aws-node DS shipped by this module)."
                )
                overall_ok = False
                continue

            subnet_id = self._find_subnet(
                instance_info["vpc_id"], instance_info["az"], subnet_pattern
            )
            if not subnet_id:
                logger.error(
                    f"No subnet matching '{subnet_pattern}' found in "
                    f"{instance_info['az']} — expected for {eni_type} ENI"
                )
                overall_ok = False
                continue

            logger.info(f"Using {eni_type} subnet: {subnet_id} (device {device_index})")
            if not self._create_and_attach_eni(subnet_id, device_index, eni_type):
                overall_ok = False

        return overall_ok


def main():
    manager = ENIAttachmentManager()
    if not manager.instance_id:
        logger.error("Could not get instance ID")
        return False
    logger.info(f"Starting ENI management for instance {manager.instance_id}")
    if manager.setup_additional_enis():
        logger.info("ENI setup completed successfully")
        return True
    logger.error("ENI setup failed")
    return False


if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
