# build-ova.ps1 — Build and package Kali OVA template for vSphere
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
if (-not $sshPass) {
    Write-Warn "PKR_VAR_build_ssh_pass environment variable not set"
    Write-Warn "Set it with: `$env:PKR_VAR_build_ssh_pass='your-password'"
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

Write-Info "Building OVA template (this may take 20-40 minutes)..."
Write-Info "You can monitor progress in the VMware hypervisor UI"

$buildCmd = "packer build -var-file='$VarsFile' $PackerFile"
$buildResult = Invoke-Cmd $buildCmd

if ($LASTEXITCODE -eq 0) {
    Write-Info ""
    Write-Info "✓ Build completed successfully!"

    # Find output OVA
    $ovaFiles = Get-ChildItem -Path "output-ova" -Filter "*.ova" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending

    if ($ovaFiles) {
        $latestOva = $ovaFiles[0]
        $ovaSize = "{0:N2} GB" -f ($latestOva.Length / 1GB)
        Write-Info ""
        Write-Info "OVA File: $($latestOva.Name)"
        Write-Info "Size: $ovaSize"
        Write-Info "Location: $(Resolve-Path $latestOva.FullName)"
        Write-Info ""
        Write-Info "Next Steps:"
        Write-Info "  1. Read OVA-UPLOAD-GUIDE.md for detailed upload instructions"
        Write-Info "  2. Upload via vSphere UI or ovftool command-line"
        Write-Info "  3. Deploy test VMs from the template"
    }
} else {
    Write-Err "Build failed. Check output above for details."
}
