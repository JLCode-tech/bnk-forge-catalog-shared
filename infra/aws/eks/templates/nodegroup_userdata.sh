#!/bin/bash
# infrastructure-modules/foundation/eks/templates/nodegroup_userdata.sh

# Node group bootstrap script for EKS worker nodes
# This script runs on each worker node to join the EKS cluster

set -o xtrace

# Bootstrap the node to join the EKS cluster
/etc/eks/bootstrap.sh ${cluster_name} --region ${region}

# Configure additional settings for high-performance workloads
echo 'net.core.default_qdisc = fq' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control = bbr' >> /etc/sysctl.conf
sysctl -p

# Install additional tools for debugging and monitoring
yum update -y
yum install -y htop iotop

# Configure log rotation for kubelet
cat > /etc/logrotate.d/kubelet <<EOF
/var/log/pods/*/*.log {
    rotate 5
    daily
    compress
    missingok
    notifempty
    maxage 30
    copytruncate
}
EOF

# Signal success
/opt/aws/bin/cfn-signal -e $? --stack ${cluster_name} --resource NodeGroup --region ${region} || echo "CFN signal failed"

echo "Node bootstrap completed successfully"