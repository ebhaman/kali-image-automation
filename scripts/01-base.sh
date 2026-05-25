#!/bin/bash
# scripts/01-base.sh
# Base provisioner — runs inside the VM during every Packer build (both variants).
# Installs: open-vm-tools, perl, cloud-init, rsyslog and applies full upgrade.
# Must be run as root (Packer uses: sudo -S bash {{.Path}})

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "========================================"
echo " 01-base.sh: starting base provisioning"
echo "========================================"

# ── Full system upgrade ───────────────────────────────────────────────────────
echo "[1/6] Running apt update and full upgrade..."
apt-get update -qq
apt-get upgrade -y -qq
apt-get dist-upgrade -y -qq

# ── Required packages ─────────────────────────────────────────────────────────
echo "[2/6] Installing required packages..."
apt-get install -y -qq \
  open-vm-tools \
  perl \
  cloud-init \
  rsyslog \
  curl \
  wget \
  gnupg \
  ca-certificates \
  apt-transport-https \
  jq \
  net-tools \
  unzip

# ── Enable and start open-vm-tools ────────────────────────────────────────────
echo "[3/6] Enabling open-vm-tools..."
systemctl enable open-vm-tools
systemctl start open-vm-tools || true

# ── Verify perl is available (required for VMware guest customization) ─────────
echo "[4/6] Verifying perl..."
perl --version | head -1

# ── Configure rsyslog with a forwarding stub ──────────────────────────────────
# The actual syslog endpoint is injected by cloud-init at deploy time.
# 99-cleanup.sh will NOT remove this — cloud-init overwrites SYSLOG_PLACEHOLDER.
echo "[5/6] Configuring rsyslog forwarding stub..."
cat > /etc/rsyslog.d/10-remote.conf << 'EOF'
# Remote syslog forwarding — endpoint injected by cloud-init at deploy time
# This placeholder is replaced during VM provisioning via userdata
*.* @@SYSLOG_PLACEHOLDER:514
EOF

systemctl enable rsyslog

# ── Clean apt cache ───────────────────────────────────────────────────────────
echo "[6/6] Cleaning apt cache..."
apt-get autoremove -y -qq
apt-get autoclean -qq
rm -rf /var/lib/apt/lists/*

echo "========================================"
echo " 01-base.sh: complete"
echo "========================================"
