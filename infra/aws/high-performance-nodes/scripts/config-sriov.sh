#!/bin/bash
# Configure SR-IOV after ENI attachment

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/config-sriov.log
}

log "Starting SR-IOV configuration"

# Wait for Lambda ENI attachment (expect 3 total interfaces)
MAX_WAIT=300
WAIT_TIME=0
while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    INTERFACE_COUNT=$(ls /sys/class/net/ | grep -E '^eth[0-9]+$' | wc -l)
    log "Found $INTERFACE_COUNT network interfaces"
    
    if [ $INTERFACE_COUNT -ge 3 ]; then
        log "All expected interfaces available, proceeding with configuration"
        break
    fi
    
    sleep 10
    WAIT_TIME=$((WAIT_TIME + 10))
done

# Run DPDK resource builder
python3 /opt/dpdk/dpdk-resource-builder.py 2 2

# Create SR-IOV device plugin config directory
if [ -d "/etc/pcidp/" ]; then
    rm -rf /etc/pcidp/
fi
mkdir -p /etc/pcidp/

# Copy configuration files
cp /tmp/data.txt /etc/pcidp/config.json
cp /tmp/data.txt /var/config.json

log "SR-IOV configuration completed"