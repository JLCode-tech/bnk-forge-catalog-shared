#!/usr/bin/env python3
"""
ENI Attachment Manager for EKS High-Performance Nodes
Creates and attaches the third ENI (eth2) required for DPDK
"""

import boto3
import json
import logging
import os
import requests
import time
import subprocess
from typing import Dict, List, Optional

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ENIAttachmentManager:
    def __init__(self):
        self.ec2_client = boto3.client('ec2')
        self.region = os.environ.get('AWS_DEFAULT_REGION', 'ap-southeast-2')
        self.instance_id = self._get_instance_id()
        self.security_groups = os.environ.get('SECURITY_GROUP_IDS', '').split(',')
        
    def _get_instance_id(self) -> str:
        """Get instance ID from metadata service."""
        try:
            token_response = requests.put(
                'http://169.254.169.254/latest/api/token',
                headers={'X-aws-ec2-metadata-token-ttl-seconds': '21600'},
                timeout=5
            )
            token = token_response.text
            
            response = requests.get(
                'http://169.254.169.254/latest/meta-data/instance-id',
                headers={'X-aws-ec2-metadata-token': token},
                timeout=5
            )
            return response.text
        except Exception as e:
            logger.error(f"Error getting instance ID: {e}")
            return ""
    
    def _get_instance_info(self) -> Dict:
        """Get instance subnet and AZ information."""
        try:
            response = self.ec2_client.describe_instances(InstanceIds=[self.instance_id])
            instance = response['Reservations'][0]['Instances'][0]
            
            return {
                'az': instance['Placement']['AvailabilityZone'],
                'subnet_id': instance['SubnetId'],
                'vpc_id': instance['VpcId']
            }
        except Exception as e:
            logger.error(f"Error getting instance info: {e}")
            return {}
    
    def _get_external_subnet(self, vpc_id: str, az: str) -> Optional[str]:
        """Find external subnet in the same AZ."""
        try:
            response = self.ec2_client.describe_subnets(
                Filters=[
                    {'Name': 'vpc-id', 'Values': [vpc_id]},
                    {'Name': 'availability-zone', 'Values': [az]},
                    {'Name': 'tag:Name', 'Values': ['*private-external*']}
                ]
            )
            
            if response['Subnets']:
                return response['Subnets'][0]['SubnetId']
            return None
        except Exception as e:
            logger.error(f"Error finding external subnet: {e}")
            return None
    
    def _get_existing_enis(self) -> List[Dict]:
        """Get existing ENIs attached to this instance."""
        try:
            response = self.ec2_client.describe_network_interfaces(
                Filters=[
                    {'Name': 'attachment.instance-id', 'Values': [self.instance_id]}
                ]
            )
            return response['NetworkInterfaces']
        except Exception as e:
            logger.error(f"Error getting existing ENIs: {e}")
            return []
    
    def _get_next_device_index(self) -> int:
        """Get the next available device index."""
        existing_enis = self._get_existing_enis()
        used_indices = []
        
        for eni in existing_enis:
            if eni.get('Attachment'):
                used_indices.append(eni['Attachment']['DeviceIndex'])
        
        # Find next available index (starting from 2)
        for i in range(2, 10):
            if i not in used_indices:
                return i
        
        return 2  # fallback
    
    def _create_and_attach_eni(self, subnet_id: str) -> bool:
        """Create and attach external ENI to the instance."""
        try:
            logger.info(f"Creating external ENI in subnet {subnet_id}")
            create_response = self.ec2_client.create_network_interface(
                SubnetId=subnet_id,
                Groups=self.security_groups,
                Description=f"External ENI for high-performance node {self.instance_id}",
                TagSpecifications=[
                    {
                        'ResourceType': 'network-interface',
                        'Tags': [
                            {'Key': 'Name', 'Value': f"{self.instance_id}-external"},
                            {'Key': 'node.k8s.amazonaws.com/no_manage', 'Value': 'true'},
                            {'Key': 'ENIType', 'Value': 'external-dpdk'}
                        ]
                    }
                ]
            )
            
            eni_id = create_response['NetworkInterface']['NetworkInterfaceId']
            logger.info(f"Created ENI {eni_id}")
            
            # Wait for ENI to be available
            time.sleep(10)
            
            # Attach ENI
            device_index = self._get_next_device_index()
            logger.info(f"Attaching ENI {eni_id} to instance {self.instance_id} at device index {device_index}")
            
            attach_response = self.ec2_client.attach_network_interface(
                NetworkInterfaceId=eni_id,
                InstanceId=self.instance_id,
                DeviceIndex=device_index
            )
            
            logger.info(f"Successfully attached external ENI {eni_id}")
            
            # Wait for attachment to complete
            time.sleep(15)
            
            # Verify the interface is available
            self._verify_interface(device_index)
            
            return True
            
        except Exception as e:
            logger.error(f"Error creating/attaching external ENI: {e}")
            return False
    
    def _verify_interface(self, expected_device_index: int):
        """Verify the new interface is available in the OS."""
        try:
            # Check if the interface appears in the system
            result = subprocess.run(['ip', 'link', 'show'], capture_output=True, text=True)
            logger.info(f"Network interfaces after ENI attachment:\n{result.stdout}")
            
            # The new interface should be eth{device_index}
            expected_interface = f"eth{expected_device_index}"
            if expected_interface in result.stdout:
                logger.info(f"Successfully verified {expected_interface} is available")
            else:
                logger.warning(f"{expected_interface} not found in interface list")
                
        except Exception as e:
            logger.error(f"Error verifying interface: {e}")
    
    def setup_additional_enis(self) -> bool:
        """Setup additional ENIs if they don't exist."""
        logger.info("Starting ENI attachment process")
        
        existing_enis = self._get_existing_enis()
        logger.info(f"Found {len(existing_enis)} existing ENIs")
        
        # If we already have 3+ ENIs, we're done
        if len(existing_enis) >= 3:
            logger.info("Already have sufficient ENIs (3+)")
            return True
        
        # Get instance information
        instance_info = self._get_instance_info()
        if not instance_info:
            logger.error("Could not get instance information")
            return False
        
        logger.info(f"Instance in AZ: {instance_info['az']}, VPC: {instance_info['vpc_id']}")
        
        # Find external subnet in same AZ
        external_subnet = self._get_external_subnet(instance_info['vpc_id'], instance_info['az'])
        if not external_subnet:
            logger.error("Could not find external subnet in same AZ")
            return False
        
        logger.info(f"Using external subnet: {external_subnet}")
        
        # Create and attach the external ENI
        return self._create_and_attach_eni(external_subnet)

def main():
    manager = ENIAttachmentManager()
    
    if not manager.instance_id:
        logger.error("Could not get instance ID")
        return False
    
    logger.info(f"Starting ENI management for instance {manager.instance_id}")
    
    # Setup additional ENIs
    if manager.setup_additional_enis():
        logger.info("ENI setup completed successfully")
        return True
    else:
        logger.error("ENI setup failed")
        return False

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)