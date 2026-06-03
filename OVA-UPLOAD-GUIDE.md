## OVA Template Build & Upload Guide

### What You Now Have

The `kali-ova.pkr.hcl` uses `vsphere-iso` (same as your existing builds) with automatic OVA export to vSphere content library.

**How it works:**
1. Builds VM in your vSphere cluster (like `kali-basic` and `kali-custom`)
2. Automatically exports OVF/OVA to your content library
3. VM is destroyed after export (`destroy = true`)
4. Result: OVA template ready in content library

---

### Building the OVA Template

#### Prerequisites
- Packer 1.8.0+
- vSphere credentials (same as your existing `kali-basic.pkr.hcl`)
- Kali ISO URL configured

#### Build Command

```bash
# Validate
packer validate -var-file="build.pkrvars.hcl" kali-ova.pkr.hcl

# Build
packer build -var-file="build.pkrvars.hcl" kali-ova.pkr.hcl
```

**Output:** Template directly in your vSphere content library (automatic)

---

### What Happens During Build

1. ✅ Packer creates VM in vSphere cluster
2. ✅ Runs provisioning scripts (base packages, SOC tools, cloud-init, cleanup)
3. ✅ Exports VM as OVF/OVA to content library
4. ✅ Cleans up build VM
5. ✅ Template available immediately in content library

**Build time:** ~20-40 minutes (network/package download dependent)

---

### OVA Template Properties

**Delivered with:**
- ✅ VMware Tools installed
- ✅ cloud-init configured for vSphere  
- ✅ SELinux/AppArmor compliance
- ✅ SSH key-based auth ready
- ✅ Disk thin-provisioned
- ✅ Network DHCP-ready

**Default Specs:**
- vCPUs: 2 (configurable)
- RAM: 4GB (configurable)
- Disk: 40GB (configurable)
- Guest OS: Debian 12 64-bit

---

### Deployment from Template

Once in content library:

#### vSphere UI
1. Go to **Content Libraries** → Your Library
2. Find `kali-ova-YYYY-WXX` template
3. **Right-click** → **New VM from This Template**
4. Configure VM settings
5. Deploy

#### CLI with govc
```bash
govc library.deploy \
  -pool=<resource-pool> \
  -ds=<datastore> \
  -n=my-kali-vm \
  /MyLibrary/kali-ova-2025-W01
```

#### CLI with ovftool
```bash
ovftool \
  "vi://user:pass@vcenter/MyLibrary/kali-ova-2025-W01" \
  "vi://user:pass@vcenter/Datacenter/vm/MyFolder/?dsName=ds-vm&vmFolder=MyFolder"
```

---

### Configuration

Edit `kali-ova.pkrvars.hcl` to customize:

```hcl
cpu_count = 4         # More vCPUs
ram_mb    = 8192      # More RAM
disk_gb   = 80        # Larger disk
```

Edit `kali-ova.pkr.hcl` to modify:

```hcl
content_library_destination {
  library     = "MyCustomLibrary"           # Different library
  name        = "custom-template-name"      # Custom name
  description = "Your custom description"   # Custom description
  ovf         = true                         # Always OVF format
  destroy     = true                         # Clean up VM after export
}
```

---

### Troubleshooting

| Issue | Solution |
|-------|----------|
| Build fails at connection | Verify vCenter credentials in `build.pkrvars.hcl` |
| ISO not found | Check `kali_iso_url` is correct and accessible |
| SSH timeout | Increase `ssh_timeout` in `kali-ova.pkr.hcl` |
| Template not in library | Check `content_library` name matches exactly |
| Provisioning fails | Verify scripts/ directory exists and is readable |

---

### Advanced: Multiple Variants

Create variant files for different purposes:

**kali-ova-minimal.pkrvars.hcl** (smaller template)
```hcl
cpu_count = 1
ram_mb    = 2048
disk_gb   = 20
```

**kali-ova-soc.pkrvars.hcl** (current, with SOC tools)
```hcl
cpu_count = 4
ram_mb    = 8192
disk_gb   = 60
```

Build each variant:
```bash
packer build -var-file="kali-ova-minimal.pkrvars.hcl" kali-ova.pkr.hcl
packer build -var-file="kali-ova-soc.pkrvars.hcl" kali-ova.pkr.hcl
```

Result: Multiple templates in content library for different use cases

---

### Cleanup & Archiving

The build VM is automatically destroyed after OVA export (`destroy = true` in config).

To keep the OVA in version control:
```bash
# After successful build, download from vSphere
# Or reference the template by its library ID
govc library.ls /MyLibrary/
```

---

### Differences from Direct Clone

| Aspect | OVA Template | Direct Clone |
|--------|-------------|--------------|
| **Storage** | Content library | Datastore |
| **Portability** | Can move between datacenters | Tied to datastore |
| **Versioning** | Easy to version | Requires manual tracking |
| **Deployment speed** | Slightly slower (library import) | Very fast |
| **Use case** | Golden image distribution | One-off builds |


