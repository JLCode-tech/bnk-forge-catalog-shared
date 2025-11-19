#!/usr/bin/env python3
# DPDK resource configuration builder

import json
import sys

def create_sriov_config(starting_interface=2, subnet_count=2):
    """Create SR-IOV device plugin configuration"""
    
    # Base configuration for SR-IOV device plugin
    config = {
        "resourceList": [
            {
                "resourceName": "internal_netdevice",
                "selectors": {
                    "vendors": ["1d0f"],
                    "devices": ["ec20"],
                    "drivers": ["ena", "vfio-pci"],
                    "pciAddresses": ["0000:00:06.0"]
                }
            },
            {
                "resourceName": "external_netdevice", 
                "selectors": {
                    "vendors": ["1d0f"],
                    "devices": ["ec20"],
                    "drivers": ["ena", "vfio-pci"],
                    "pciAddresses": ["0000:00:07.0"]
                }
            }
        ]
    }
    
    return config

if __name__ == "__main__":
    starting_interface = int(sys.argv[1]) if len(sys.argv) > 1 else 2
    subnet_count = int(sys.argv[2]) if len(sys.argv) > 2 else 2
    
    config = create_sriov_config(starting_interface, subnet_count)
    
    # Write to temporary file
    with open('/tmp/data.txt', 'w') as f:
        json.dump(config, f, indent=2)
    
    print("SR-IOV configuration created successfully")