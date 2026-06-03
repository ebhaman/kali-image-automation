# kali-ova.build.pkrvars.hcl
# Complete build variables for kali-ova.pkr.hcl validation and builds
# Sensitive values should come from environment variables or GitHub Secrets

# ── vSphere Connection ────────────────────────────────────────────────────────
# These will be overridden by GitHub Secrets in CI/CD
vcenter_host      = "vcenter.example.com"
vcenter_user      = "svc-packer@vsphere.local"
vcenter_pass      = "placeholder"  # Set via PKR_VAR_vcenter_pass env var
insecure_connection = false

# ── vSphere Placement ─────────────────────────────────────────────────────────
datacenter      = "Datacenter1"
cluster         = "ComputeCluster"
datastore       = "ds-vm-storage"
build_network   = "VM Network"
content_library = "Templates"

# ── ISO Configuration ─────────────────────────────────────────────────────────
# Update these with actual Kali ISO details
kali_iso_url    = "https://cdimage.kali.org/kali-2025.1/kali-linux-2025.1-installer-amd64.iso"
kali_iso_sha256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"  # Replace with actual SHA256

# ── Build Credentials ─────────────────────────────────────────────────────────
# Temporary SSH password for Packer provisioning
# Set via PKR_VAR_build_ssh_pass environment variable for security
build_ssh_pass = "TempPacker123!"

# ── VM Sizing ─────────────────────────────────────────────────────────────────
cpu_count = 2       # vCPUs
ram_mb    = 4096    # RAM in megabytes
disk_gb   = 40      # Primary disk in gigabytes
