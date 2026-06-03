# OVA Template Implementation Summary

Created a complete OVA template build pipeline for Kali Linux that produces deployable VM templates for vSphere content library.

## Files Created

### 1. **kali-ova.pkr.hcl** (Core Packer Template)
   - `vmware-iso` builder (works locally or on ESXi)
   - Generates OVA output (portable, uploadable)
   - Includes provisioning scripts for base OS + tools
   - cloud-init configuration for vSphere
   - Output: `output-ova/kali-ova-YYYY-MM-DD-hhmm.ova`

### 2. **kali-ova.pkrvars.hcl** (Build Variables)
   - Template for configuring hardware specs (CPU, RAM, disk)
   - ISO URL and checksum configuration
   - Non-sensitive, can be committed to git

### 3. **OVA-UPLOAD-GUIDE.md** (Complete Reference)
   - How to build the OVA
   - Three upload methods (UI, ovftool, govc)
   - Deployment instructions
   - Troubleshooting guide

### 4. **build-ova.sh** (Bash Build Script)
   - For Linux/macOS/WSL environments
   - Validates prerequisites
   - Shows real-time progress
   - Verifies output

### 5. **build-ova.ps1** (PowerShell Build Script)
   - For Windows native environments
   - Same functionality as bash script
   - No additional dependencies

## Quick Start

### Windows (PowerShell)
```powershell
# Set build credentials
$env:PKR_VAR_build_ssh_pass = 'your-temp-password'

# Configure ISO in kali-ova.pkrvars.hcl, then build:
.\build-ova.ps1
```

### Linux/macOS/WSL
```bash
# Set build credentials
export PKR_VAR_build_ssh_pass="your-temp-password"

# Configure ISO in kali-ova.pkrvars.hcl, then build:
chmod +x build-ova.sh
./build-ova.sh
```

### Manual Packer Commands
```bash
# Validate
packer validate -var-file="kali-ova.pkrvars.hcl" kali-ova.pkr.hcl

# Build
packer build -var-file="kali-ova.pkrvars.hcl" kali-ova.pkr.hcl
```

## How It Differs from Existing Builds

| Feature | kali-basic/custom | kali-ova |
|---------|-------------------|----------|
| **Builder** | vsphere-iso (requires vCenter) | vmware-iso (local or ESXi) |
| **Output** | Direct to content library | OVA file on disk |
| **Upload** | Automatic | Manual (UI/ovftool/govc) |
| **Use Case** | CI/CD automation | Archiving, manual uploads |
| **Dependencies** | vCenter credentials | VMware hypervisor only |

**Your existing builds stay unchanged** — this is an _additional_ option for scenarios where you want a standalone, portable OVA.

## Integration with Content Library

Once built, the OVA can be uploaded to vSphere content library for:
- ✅ Versioned template management
- ✅ Multi-datacenter distribution
- ✅ Quick clone deployment
- ✅ API-driven provisioning (Terraform, cloud-init)

## Key Configuration Points

Edit `kali-ova.pkrvars.hcl`:
- **cpu_count**: vCPU allocation (default: 2)
- **ram_mb**: RAM in MB (default: 4096)
- **disk_gb**: Disk size in GB (default: 40)

Edit `kali-ova.pkr.hcl` if you need:
- Different tools/packages (modify scripts/)
- Custom metadata in OVA
- Additional provisioning steps
- Different guest OS type

## Next Steps

1. **Configure ISO**
   - Download Kali ISO from kali.org
   - Update `kali_iso_url` and `kali_iso_sha256` in `kali-ova.pkrvars.hcl`

2. **Set Credentials**
   ```bash
   export PKR_VAR_build_ssh_pass="TempPassword123!"
   ```

3. **Validate Configuration**
   ```bash
   packer validate -var-file="kali-ova.pkrvars.hcl" kali-ova.pkr.hcl
   ```

4. **Build OVA**
   ```bash
   packer build -var-file="kali-ova.pkrvars.hcl" kali-ova.pkr.hcl
   ```

5. **Upload to vSphere Content Library**
   - See OVA-UPLOAD-GUIDE.md for detailed instructions

## Support

- **OVA-UPLOAD-GUIDE.md** — Complete upload and deployment guide
- **Packer Docs** — https://www.packer.io/docs/builders/vmware/iso
- **vSphere Content Library** — https://docs.vmware.com/en/vSphere/

---

**Questions?** Check OVA-UPLOAD-GUIDE.md troubleshooting section or your Packer logs.
