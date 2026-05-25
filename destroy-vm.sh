#!/bin/bash
# destroy-vm.sh
# Destroys an expired Kali pentest VM.
# Can be called by Snow Commander lifecycle controller or run manually.
# Also usable as a cron job to auto-destroy expired VMs based on ExpiryDate
# custom attribute.
#
# Usage:
#   # Destroy a specific VM:
#   ./destroy-vm.sh --vm-name "KaliVM-ZD-XXX-001-REQ001"
#
#   # Destroy all VMs past their expiry date (for cron mode):
#   ./destroy-vm.sh --expired
#
# Required environment variables:
#   GOVC_URL / GOVC_USERNAME / GOVC_PASSWORD / GOVC_INSECURE

set -euo pipefail

PENTEST_FOLDER="${PENTEST_FOLDER:-/DC/vm/pentest}"
TODAY=$(date +%Y-%m-%d)

destroy_vm() {
  local VM_NAME="$1"
  echo "Destroying: $VM_NAME"

  # Power off gracefully first
  POWER=$(govc vm.info "$VM_NAME" 2>/dev/null | grep "Power state" | awk '{print $NF}' || echo "unknown")
  if [ "$POWER" = "poweredOn" ]; then
    echo "  Powering off..."
    govc vm.power -off -force "$VM_NAME" 2>/dev/null || true
    sleep 10
  fi

  # Destroy
  govc vm.destroy "$VM_NAME"
  echo "  Destroyed: $VM_NAME"
}

# ── Parse arguments ───────────────────────────────────────────────────────────
MODE="single"
VM_NAME=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --vm-name) VM_NAME="$2"; shift 2 ;;
    --expired) MODE="expired"; shift ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

# ── Single VM destroy ─────────────────────────────────────────────────────────
if [ "$MODE" = "single" ]; then
  if [ -z "$VM_NAME" ]; then
    echo "ERROR: --vm-name is required in single mode"
    exit 1
  fi
  destroy_vm "$VM_NAME"
  exit 0
fi

# ── Expired VM sweep (cron mode) ──────────────────────────────────────────────
echo "Sweeping for expired Kali VMs (expiry <= $TODAY)..."
echo ""

# List all VMs in the pentest folder
ALL_VMS=$(govc ls "${PENTEST_FOLDER}/..." 2>/dev/null | grep "KaliVM-" || true)

if [ -z "$ALL_VMS" ]; then
  echo "No Kali VMs found in $PENTEST_FOLDER"
  exit 0
fi

DESTROYED=0
SKIPPED=0

while IFS= read -r VM_PATH; do
  VM_NAME=$(basename "$VM_PATH")

  # Read ExpiryDate custom attribute
  EXPIRY=$(govc fields.ls "$VM_NAME" 2>/dev/null \
    | grep "ExpiryDate" | awk '{print $NF}' || echo "")

  if [ -z "$EXPIRY" ]; then
    echo "SKIP (no expiry date): $VM_NAME"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  if [[ "$EXPIRY" < "$TODAY" || "$EXPIRY" == "$TODAY" ]]; then
    echo "EXPIRED ($EXPIRY): $VM_NAME — destroying..."
    destroy_vm "$VM_NAME"
    DESTROYED=$((DESTROYED + 1))
  else
    echo "ACTIVE  ($EXPIRY): $VM_NAME — skipping"
    SKIPPED=$((SKIPPED + 1))
  fi
done <<< "$ALL_VMS"

echo ""
echo "Sweep complete — destroyed: $DESTROYED, skipped: $SKIPPED"
