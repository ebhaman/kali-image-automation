#!/bin/bash
# scripts/02-soc-tools.sh
# SOC toolset provisioner — custom variant only.
# Installs the Ansible playbook runner and executes ansible/soc-tools.yml.
# Must be run as root (Packer uses: sudo -S bash {{.Path}})

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "========================================"
echo " 02-soc-tools.sh: installing SOC tools"
echo "========================================"

# ── Install Ansible ───────────────────────────────────────────────────────────
echo "[1/3] Installing Ansible..."
apt-get update -qq
apt-get install -y -qq ansible python3-pip python3-venv

# Verify
ansible --version | head -1

# ── Copy playbook from /tmp (Packer file provisioner places it there) ──────────
# The playbook is uploaded by a separate file provisioner in the build block.
# If running this script standalone, place ansible/soc-tools.yml at /tmp/soc-tools.yml
echo "[2/3] Running SOC tools Ansible playbook..."

if [ -f /tmp/soc-tools.yml ]; then
  ansible-playbook /tmp/soc-tools.yml -c local \
    -e "ansible_python_interpreter=/usr/bin/python3" \
    --diff
else
  # Fallback: install a standard SOC toolset directly if playbook not present
  echo "WARNING: Playbook not found — installing default SOC package set"
  apt-get install -y -qq \
    nmap \
    ncat \
    masscan \
    wireshark-common \
    tshark \
    tcpdump \
    netcat-traditional \
    socat \
    curl \
    wget \
    dnsutils \
    whois \
    traceroute \
    nikto \
    dirb \
    gobuster \
    sqlmap \
    hydra \
    john \
    hashcat \
    metasploit-framework \
    burpsuite \
    zaproxy \
    sslscan \
    testssl.sh \
    enum4linux \
    smbclient \
    crackmapexec \
    impacket-scripts \
    python3-impacket \
    responder \
    bloodhound \
    neo4j \
    steghide \
    exiftool \
    binwalk \
    foremost \
    volatility3 \
    autopsy \
    git \
    python3-pip \
    golang-go \
    ruby
fi

# ── Clean up ──────────────────────────────────────────────────────────────────
echo "[3/3] Cleaning up..."
rm -f /tmp/soc-tools.yml
apt-get autoremove -y -qq
apt-get autoclean -qq
rm -rf /var/lib/apt/lists/*

echo "========================================"
echo " 02-soc-tools.sh: complete"
echo "========================================"
