Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="
MIME-Version: 1.0

--==MYBOUNDARY==
Content-Type: text/cloud-boothook; charset="us-ascii"
#!/bin/bash
# CLOUD BOOTHOOK: Runs very early, before everything else.
# Sets GRUB kernel params for hugepages AND creates the reboot service.
# EKS managed node groups may not properly merge bootstrap.sh when
# MIME multipart user_data is provided, so we explicitly call it in the
# text/x-shellscript part below.

exec >> /var/log/boothook-hugepages.log 2>&1

STATE_DIR="/var/lib/dpdk-setup"
mkdir -p "$STATE_DIR"

# Skip if hugepages already active (post-reboot)
if grep -q "hugepagesz=2M" /proc/cmdline 2>/dev/null; then
    echo "[$(date)] Hugepages active in cmdline. Done."
    touch "$STATE_DIR/hugepages_active"
    exit 0
fi

# Skip if already configured
if [ -f "$STATE_DIR/grub_configured" ]; then
    echo "[$(date)] GRUB already configured."
    exit 0
fi

echo "[$(date)] === Configuring hugepages ==="

# --- GRUB kernel params ---
KP="default_hugepagesz=2M hugepagesz=2M hugepages=${hugepages_2mi} hugepagesz=1G hugepages=${hugepages_1gi} intel_iommu=on iommu=pt"

if [ -f /etc/default/grub ]; then
    cp /etc/default/grub /etc/default/grub.bak.hp
    # AL2 uses GRUB_CMDLINE_LINUX_DEFAULT, try both patterns
    if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
        sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\"|GRUB_CMDLINE_LINUX_DEFAULT=\"$KP |" /etc/default/grub
    elif grep -q '^GRUB_CMDLINE_LINUX=' /etc/default/grub; then
        sed -i "s|^GRUB_CMDLINE_LINUX=\"|GRUB_CMDLINE_LINUX=\"$KP |" /etc/default/grub
    else
        echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$KP\"" >> /etc/default/grub
    fi
    grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true
    echo "[$(date)] GRUB configured: $(grep GRUB_CMDLINE /etc/default/grub)"
fi

# --- Runtime hugepages (best effort) ---
echo ${hugepages_2mi} > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages 2>/dev/null || true
mkdir -p /mnt/huge-2m /mnt/huge-1g
mount -t hugetlbfs -o pagesize=2M nodev /mnt/huge-2m 2>/dev/null || true
mount -t hugetlbfs -o pagesize=1G nodev /mnt/huge-1g 2>/dev/null || true
echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
echo never > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true

# --- sysctl optimizations ---
cat > /etc/sysctl.d/99-dpdk.conf << 'SYSCTL'
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.rp_filter = 0
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
SYSCTL
sysctl --system 2>/dev/null || true

# --- Post-bootstrap reboot service ---
# Creates a systemd service that waits for kubelet, then reboots ONCE.
cat > /usr/local/bin/post-bootstrap-reboot.sh << 'REBOOT'
#!/bin/bash
exec >> /var/log/post-bootstrap-reboot.log 2>&1
SENTINEL="/var/lib/dpdk-setup/reboot_completed"
[ -f "$SENTINEL" ] && exit 0
grep -q "hugepagesz=2M" /proc/cmdline && { touch "$SENTINEL"; exit 0; }
[ ! -f "/var/lib/dpdk-setup/grub_configured" ] && exit 0
echo "[$(date)] Waiting for kubelet..."
for i in $(seq 1 120); do
    systemctl is-active kubelet >/dev/null 2>&1 && break
    sleep 5
done
echo "[$(date)] Kubelet active. Waiting 5 min for EKS to register node..."
sleep 300
echo "[$(date)] Rebooting for hugepages..."
touch "$SENTINEL"
sync
reboot
REBOOT
chmod +x /usr/local/bin/post-bootstrap-reboot.sh

cat > /etc/systemd/system/post-bootstrap-reboot.service << 'SVC'
[Unit]
Description=One-time reboot for hugepages activation
After=kubelet.service
Wants=kubelet.service
[Service]
Type=oneshot
ExecStart=/usr/local/bin/post-bootstrap-reboot.sh
RemainAfterExit=yes
TimeoutStartSec=900
[Install]
WantedBy=multi-user.target
SVC
systemctl daemon-reload
systemctl enable post-bootstrap-reboot.service

touch "$STATE_DIR/grub_configured"
echo "[$(date)] === Boothook complete. Reboot will happen after EKS bootstrap + 5min. ==="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
#!/bin/bash
# EKS BOOTSTRAP: Explicitly call bootstrap.sh to join the cluster.
# When using a custom launch template with MIME multipart user_data,
# EKS managed node groups may not properly append the bootstrap script.
# Calling it explicitly ensures the node always joins the cluster.

set -o xtrace
exec >> /var/log/eks-bootstrap.log 2>&1

echo "[$(date)] Starting EKS bootstrap for cluster ${cluster_name}"

# Bootstrap the node to join the EKS cluster
/etc/eks/bootstrap.sh '${cluster_name}' --region '${region}'

echo "[$(date)] EKS bootstrap completed"

# Start the post-bootstrap reboot service explicitly.
# The boothook created and enabled it, but systemd may have already
# passed multi-user.target before the service was registered.
if [ -f /etc/systemd/system/post-bootstrap-reboot.service ]; then
    echo "[$(date)] Starting post-bootstrap-reboot service..."
    nohup bash -c 'sleep 10 && /usr/local/bin/post-bootstrap-reboot.sh' >> /var/log/post-bootstrap-reboot.log 2>&1 &
fi

--==MYBOUNDARY==--
