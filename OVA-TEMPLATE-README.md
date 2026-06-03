# OVA Template Implementation Summary

Created a simplified OVA template build that uses your existing vSphere infrastructure. It builds and exports to content library automatically—no additional plugins needed.

## How It Works

- **Source:** `vsphere-iso` (same as your existing `kali-basic.pkr.hcl`)
- **Build:** Creates VM in vSphere cluster
- **Export:** Automatically exports as OVF/OVA to content library
- **Cleanup:** Build VM is destroyed after export
- **Result:** Ready-to-deploy template in content library

## Files Created

- **kali-ova.pkr.hcl** — Packer template (vsphere-iso builder)
- **kali-ova.pkrvars.hcl** — Build configuration variables
- **OVA-UPLOAD-GUIDE.md** — Complete build & deployment guide
- **build-ova.ps1** — Windows PowerShell build script
- **build-ova.sh** — Linux/macOS/WSL bash script

## Quick Start

### 1. Configure ISO
Edit `kali-ova.pkrvars.hcl` or create a build-time override:
```bash
# Validate
packer validate -var-file="build.pkrvars.hcl" kali-ova.pkr.hcl

# Build
packer build -var-file="build.pkrvars.hcl" kali-ova.pkr.hcl
```

### 2. Or Use Build Scripts

**Windows:**
```powershell
$env:PKR_VAR_build_ssh_pass = "YourPassword"
.\build-ova.ps1
```

**Linux/macOS:**
```bash
export PKR_VAR_build_ssh_pass="YourPassword"
./build-ova.sh
```

### 3. Deploy from Content Library

Once build completes, template appears in your content library:
- **UI:** Right-click template → "New VM from This Template"
- **CLI:** Use `govc library.deploy` or vSphere Terraform provider

## Differences from Your Existing Builds

| Feature | kali-basic/custom | kali-ova |
|---------|-------------------|----------|
| Builder | vsphere-iso | vsphere-iso (same) |
| Provisioning | Custom tools | SOC tools + base |
| Export | Direct to library | Auto-export OVA |
| VM Cleanup | Auto (destroy=true) | Auto (destroy=true) |
| Use Case | Daily builds | Golden image version |

**No new plugins needed** — uses your existing Packer setup!

## Configuration

**Hardware sizing** (edit `kali-ova.pkrvars.hcl`):
```hcl
cpu_count = 2       # vCPUs
ram_mb    = 4096    # RAM in MB
disk_gb   = 40      # Disk in GB
```

**Content library** (edit `kali-ova.pkr.hcl`):
```hcl
content_library_destination {
  library     = var.content_library    # Your existing library
  name        = local.ova_template_name
  description = "Kali Linux OVA template"
  ovf         = true                    # OVF/OVA format
  destroy     = true                    # Clean up after export
}
```

## Build Time

Expect **20-40 minutes** depending on:
- Network speed (ISO download)
- Package installation time
- vSphere performance

## Next Steps

1. **Read OVA-UPLOAD-GUIDE.md** for detailed instructions
2. **Run build:** `packer build -var-file="build.pkrvars.hcl" kali-ova.pkr.hcl`
3. **Deploy test VM** from content library
4. **Verify** template works as expected

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `Unknown source type vsphere-iso` | Ensure you're using Packer 1.8+ with vSphere plugin |
| SSH timeout | Increase `ssh_timeout` value in `kali-ova.pkr.hcl` |
| Build fails to connect | Verify vCenter credentials in `build.pkrvars.hcl` |
| ISO not found | Check `kali_iso_url` is accessible and SHA256 is correct |

See OVA-UPLOAD-GUIDE.md for more troubleshooting.

## What You Get

✅ OVA template in content library  
✅ Automated provisioning with SOC tools  
✅ cloud-init ready for vSphere  
✅ Thin-provisioned disk  
✅ VMware Tools included  
✅ Reusable build scripts  

---

**Questions?** Check OVA-UPLOAD-GUIDE.md or your Packer logs.

