## OVA Template Build & Upload Guide

### What You Now Have

Two build strategies:

1. **Direct Content Library Upload** (existing `kali-basic.pkr.hcl`, `kali-custom.pkr.hcl`)
   - Builds VM in vSphere
   - Automatically uploads OVF to vSphere content library
   - Fastest for continuous integration

2. **Standalone OVA File** (new `kali-ova.pkr.hcl`)
   - Builds VM locally using VMware Workstation/Player/ESXi
   - Outputs portable `.ova` file to `output-ova/` directory
   - Can be uploaded manually or archived

---

### Building the OVA Template

#### Prerequisites
- **Packer** 1.8.0+
- **VMware Player/Pro/Fusion** or ESXi host (for remote build)
- **OVFtool** (optional, for additional export options)
- Kali ISO pre-downloaded or URL accessible

#### Build the OVA

```bash
# Validate configuration
packer validate -var-file="build.pkrvars.hcl" kali-ova.pkr.hcl

# Build the OVA
packer build -var-file="build.pkrvars.hcl" kali-ova.pkr.hcl
```

**Output:** `output-ova/kali-ova-YYYY-MM-DD-hhmm.ova` (~5-15 GB depending on packages)

---

### Uploading OVA to vSphere Content Library

#### Option A: vSphere UI (Easiest)
1. Go to **Content Libraries** → Select your library
2. Click **Upload Item**
3. Select the `.ova` file
4. Fill in metadata:
   - **Name:** `kali-linux-template-YYYY-MM-DD`
   - **Description:** `Kali Linux template with SOC tools`
   - **Content type:** OVF

#### Option B: OVFtool (Command Line)
```bash
# Set vSphere credentials
export VCENTER_URL="https://vcenter.example.com"
export VCENTER_USER="svc-packer@vsphere.local"
export VCENTER_PASS="YourPassword"

# Upload OVA to content library
ovftool \
  --acceptAllEulas \
  --skipManifestCheck \
  --disableVerification \
  "kali-ova-YYYY-MM-DD-hhmm.ova" \
  "vi://${VCENTER_USER}:${VCENTER_PASS}@${VCENTER_URL}/some-datacenter/vm/templates/?dmMode=upload&dsName=your-datastore&targetName=kali-linux-template&resourcePool=Resources"
```

#### Option C: govc (if you prefer Go tooling)
```bash
# Upload to library
govc library.import \
  -ds=<datastore> \
  -pool=<resource-pool> \
  -n=kali-linux-template \
  kali-ova-YYYY-MM-DD-hhmm.ova
```

---

### OVA Template Properties

**Delivered with:**
- ✅ VMware Tools installed
- ✅ cloud-init configured for vSphere
- ✅ SELinux/AppArmor compliance
- ✅ SSH hardened, password auth disabled (use cloud-init)
- ✅ Disk space optimized (thin provisioning ready)
- ✅ Network DHCP-ready for vSphere

**Default Specs:**
- vCPUs: 2 (configurable)
- RAM: 4GB (configurable)
- Disk: 40GB (configurable, thin-provisioned)
- Guest OS: Debian 12 64-bit

---

### Deployment from Template

Once in content library:

```bash
# Example: Clone from content library template
govc vm.clone \
  -m=4096 \
  -c=2 \
  -template=<library_path>/kali-linux-template \
  -on=false \
  my-kali-vm
```

Or via vSphere UI:
1. **Right-click template** → **New VM from This Template**
2. Configure networking, storage, etc.
3. Deploy

---

### Troubleshooting

| Issue | Solution |
|-------|----------|
| OVA too large | Reduce disk size or remove unnecessary packages in `scripts/` |
| Import fails in content library | Ensure OVA format is valid: `ovftool kali-ova.ova /dev/null` |
| Network unreachable during build | Verify ISO URL is accessible; check firewall rules |
| SSH timeout | Increase `ssh_handshake_attempts` or `ssh_timeout` in `kali-ova.pkr.hcl` |

---

### Advanced: Custom OVA Metadata

Edit `kali-ova.pkr.hcl` to add vSphere custom fields:

```hcl
provisioner "shell" {
  inline = [
    "sudo echo 'template-type=kali-soc' > /etc/vmware-tools/tools.conf.d/template.conf",
    "sudo echo 'build-date=$(date -I)' >> /etc/vmware-tools/tools.conf.d/template.conf"
  ]
}
```

Then reference in vSphere via custom attributes.

---

### Cleanup After Upload

Once verified in content library:
```bash
rm -rf output-ova/  # Remove local OVA if no longer needed
```

Keep in version control (or S3/artifact repo) for auditing.
