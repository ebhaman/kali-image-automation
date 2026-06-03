#!/usr/bin/env bash
# build-ova.sh — Build and package Kali OVA template for vSphere

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PACKER_FILE="kali-ova.pkr.hcl"
PKRVARS_FILE="kali-ova.pkrvars.hcl"
OUTPUT_DIR="output-ova"
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)

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
# Main
# ────────────────────────────────────────────────────────────────────────────

main() {
  log "Starting Kali OVA build..."

  # Verify prerequisites
  check_command packer
  check_command ssh

  [ -f "$PACKER_FILE" ] || error "Missing: $PACKER_FILE"
  [ -f "$PKRVARS_FILE" ] || error "Missing: $PKRVARS_FILE"

  # Check credentials are set
  if [ -z "${PKR_VAR_build_ssh_pass:-}" ]; then
    warn "PKR_VAR_build_ssh_pass not set. You will be prompted during Packer build."
    warn "To avoid this, set: export PKR_VAR_build_ssh_pass='your-password'"
  fi

  # Check ISO is configured
  if ! grep -q 'kali_iso_url' "$PKRVARS_FILE" || grep 'kali_iso_url.*#' "$PKRVARS_FILE"; then
    error "Configure kali_iso_url in $PKRVARS_FILE first!"
  fi

  # Validate Packer HCL
  log "Validating Packer configuration..."
  packer validate \
    -var-file="$PKRVARS_FILE" \
    "$PACKER_FILE" \
    || error "Packer validation failed"

  # Build
  log "Building OVA template (this may take 20-40 minutes)..."
  packer build \
    -var-file="$PKRVARS_FILE" \
    "$PACKER_FILE" \
    || error "Packer build failed"

  # Verify output
  if [ -d "$OUTPUT_DIR" ] && [ -n "$(ls -A "$OUTPUT_DIR"/*.ova 2>/dev/null)" ]; then
    OVA_FILE=$(ls -t "$OUTPUT_DIR"/*.ova 2>/dev/null | head -1)
    OVA_SIZE=$(du -h "$OVA_FILE" | cut -f1)
    log "✓ OVA created successfully: $OVA_FILE ($OVA_SIZE)"
    log "✓ Ready to upload to vSphere content library"
    log ""
    log "Next steps:"
    log "  1. Read OVA-UPLOAD-GUIDE.md for upload instructions"
    log "  2. Upload to content library via UI or ovftool"
    log "  3. Test clone deployment"
  else
    error "OVA file not found in $OUTPUT_DIR"
  fi
}

# ────────────────────────────────────────────────────────────────────────────

main "$@"
