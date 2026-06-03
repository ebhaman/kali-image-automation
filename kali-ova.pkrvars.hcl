# Build variables for kali-ova.pkr.hcl
# This file is NOT sensitive and can be committed to version control

# ── ISO Configuration ─────────────────────────────────────────────────────────
# Download latest from: https://www.kali.org/get-kali/
# kali_iso_url = "https://cdimage.kali.org/kali-2024.1/kali-linux-2024.1-installer-amd64.iso"
# kali_iso_sha256 = "abcd1234..." # Verify on kali.org

# ── Credentials (override with -var or environment) ───────────────────────────
# These should come from:
#   export PKR_VAR_build_ssh_pass="..."
#   OR: packer build -var 'build_ssh_pass=...'
# They must NOT be in this file for security

# ── Hardware Sizing ───────────────────────────────────────────────────────────
cpu_count = 2       # vCPUs
ram_mb    = 4096    # 4 GB
disk_gb   = 40      # 40 GB (thin-provisioned)

# ── Paths ─────────────────────────────────────────────────────────────────────
# Only used if building with VMware ESXi backend (not typical for local OVA)
# vcenter_host      = "vcenter.example.com"
# datacenter        = "Datacenter1"
# cluster           = "ComputeCluster"
# datastore         = "ds-vm-storage"
# build_network     = "VM Network"
# content_library   = "MyTemplates"

# Note: Local vmware-iso builds don't need vCenter credentials
