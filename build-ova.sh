#!/usr/bin/env bash
# build-ova.sh — Build Kali OVA template and export to vSphere content library

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PACKER_FILE="kali-ova.pkr.hcl"
PKRVARS_FILE="kali-ova.pkrvars.hcl"

# ────────────────────────────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────────────────────────────

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

check_command() {
  command -v "$1" &> /dev/null || error "Missing required: $1"
}

# ────────────────────────────────────────────────────────────────────────────
# Prerequisites Check
# ────────────────────────────────────────────────────────────────────────────

log "Checking prerequisites..."
check_command packer

[ -f "$PACKER_FILE" ] || error "Missing: $PACKER_FILE"
[ -f "$PKRVARS_FILE" ] || error "Missing: $PKRVARS_FILE"

# Check SSH credentials
if [ -z "${PKR_VAR_build_ssh_pass:-}" ]; then
  error "PKR_VAR_build_ssh_pass not set. Export: PKR_VAR_build_ssh_pass='password'"
fi

# Warn if vCenter creds missing
if [ -z "${PKR_VAR_vcenter_user:-}" ] || [ -z "${PKR_VAR_vcenter_pass:-}" ]; then
  warn "vCenter credentials not set as environment variables"
  warn "Export them or configure in .pkrvars file:"
  warn "  export PKR_VAR_vcenter_user='user@vsphere.local'"
  warn "  export PKR_VAR_vcenter_pass='password'"
fi

# ────────────────────────────────────────────────────────────────────────────
# Validate Configuration
# ────────────────────────────────────────────────────────────────────────────

log "Validating Packer configuration..."
packer validate \
  -var-file="$PKRVARS_FILE" \
  "$PACKER_FILE" \
  || error "Packer validation failed"

log "✓ Configuration valid"

# ────────────────────────────────────────────────────────────────────────────
# Build
# ────────────────────────────────────────────────────────────────────────────

log ""
log "Building Kali OVA template..."
log "  - Building VM in vSphere"
log "  - Running provisioning scripts"
log "  - Exporting as OVF/OVA to content library"
log "  - Cleaning up build VM"
log ""
log "This may take 20-40 minutes depending on network and system performance"
log ""

packer build \
  -var-file="$PKRVARS_FILE" \
  "$PACKER_FILE" \
  || error "Packer build failed"

# ────────────────────────────────────────────────────────────────────────────
# Success
# ────────────────────────────────────────────────────────────────────────────

log ""
log "╔════════════════════════════════════════════════════════════╗"
log "║ ✓ Build completed successfully!                           ║"
log "║                                                            ║"
log "║ Template is now available in your vSphere content library  ║"
log "║                                                            ║"
log "║ Next steps:                                                ║"
log "║  1. Check vSphere UI → Content Libraries                   ║"
log "║  2. Right-click template → New VM from This Template       ║"
log "║  3. Deploy and test                                        ║"
log "╚════════════════════════════════════════════════════════════╝"
