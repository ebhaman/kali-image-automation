# build-ova.ps1 — Build Kali OVA template and export to vSphere content library
# Run: .\build-ova.ps1

param(
    [switch]$SkipValidation = $false,
    [string]$PackerFile = "kali-ova.pkr.hcl",
    [string]$VarsFile = "kali-ova.pkrvars.hcl"
)

$ErrorActionPreference = "Stop"

# ────────────────────────────────────────────────────────────────────────────
# Colors and Helpers
# ────────────────────────────────────────────────────────────────────────────

function Write-Info { Write-Host -ForegroundColor Green "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $args" }
function Write-Warn { Write-Host -ForegroundColor Yellow "[WARN] $args" }
function Write-Err { Write-Host -ForegroundColor Red "[ERROR] $args"; exit 1 }

function Invoke-Cmd {
    param([string]$Cmd)
    Write-Info "Running: $Cmd"
    $output = Invoke-Expression $Cmd 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Command failed: $Cmd"
    }
    return $output
}

# ────────────────────────────────────────────────────────────────────────────
# Prerequisites Check
# ────────────────────────────────────────────────────────────────────────────

Write-Info "Checking prerequisites..."

# Check Packer
try { $packerVersion = packer version 2>&1 | Select-Object -First 1 }
catch { Write-Err "Packer not found. Install from https://www.packer.io/downloads" }
Write-Info "Found Packer: $packerVersion"

# Check files exist
if (-not (Test-Path $PackerFile)) {
    Write-Err "Missing: $PackerFile"
}
if (-not (Test-Path $VarsFile)) {
    Write-Err "Missing: $VarsFile"
}

# Check credentials
$sshPass = [Environment]::GetEnvironmentVariable("PKR_VAR_build_ssh_pass")
$vcUser = [Environment]::GetEnvironmentVariable("PKR_VAR_vcenter_user")
$vcPass = [Environment]::GetEnvironmentVariable("PKR_VAR_vcenter_pass")

if (-not $sshPass) {
    Write-Err "PKR_VAR_build_ssh_pass not set. Set with: `$env:PKR_VAR_build_ssh_pass='password'"
}

if (-not $vcUser -or -not $vcPass) {
    Write-Warn "vCenter credentials not set as environment variables"
    Write-Warn "You can set them with:"
    Write-Warn "  `$env:PKR_VAR_vcenter_user='user@vsphere.local'"
    Write-Warn "  `$env:PKR_VAR_vcenter_pass='password'"
    Write-Warn "Or configure them in your .pkrvars file"
}

# ────────────────────────────────────────────────────────────────────────────
# Validation
# ────────────────────────────────────────────────────────────────────────────

if (-not $SkipValidation) {
    Write-Info "Validating Packer configuration..."
    Invoke-Cmd "packer validate -var-file='$VarsFile' $PackerFile"
    Write-Info "✓ Configuration valid"
}

# ────────────────────────────────────────────────────────────────────────────
# Build
# ────────────────────────────────────────────────────────────────────────────

Write-Info ""
Write-Info "Building Kali OVA template..."
Write-Info "  - Building VM in vSphere"
Write-Info "  - Running provisioning scripts"
Write-Info "  - Exporting as OVF/OVA to content library"
Write-Info "  - Cleaning up build VM"
Write-Info ""
Write-Info "This may take 20-40 minutes depending on network and system performance"
Write-Info ""

$buildCmd = "packer build -var-file='$VarsFile' $PackerFile"
$buildResult = Invoke-Cmd $buildCmd

if ($LASTEXITCODE -eq 0) {
    Write-Info ""
    Write-Info "╔════════════════════════════════════════════════════════════╗"
    Write-Info "║ ✓ Build completed successfully!                           ║"
    Write-Info "║                                                            ║"
    Write-Info "║ Template is now available in your vSphere content library  ║"
    Write-Info "║                                                            ║"
    Write-Info "║ Next steps:                                                ║"
    Write-Info "║  1. Check vSphere UI → Content Libraries                   ║"
    Write-Info "║  2. Right-click template → New VM from This Template       ║"
    Write-Info "║  3. Deploy and test                                        ║"
    Write-Info "╚════════════════════════════════════════════════════════════╝"
} else {
    Write-Err "Build failed. Check the output above for error details."
}
