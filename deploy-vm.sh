#!/bin/bash
# deploy-vm.sh
# Deploys a Kali pentest VM from the vSphere Content Library template.
# Called by Snow Commander completion workflow after four-eyes approval.
# Can also be run manually for testing.
#
# Usage:
#   ./deploy-vm.sh \
#     --zone         ZD-XXX-001 \
#     --request-id   REQ-20260525-001 \
#     --requester    "j.doe" \
#     --static-ip    10.20.30.100 \
#     --prefix       24 \
#     --gateway      10.20.30.1 \
#     --dns1         10.0.0.10 \
#     --dns2         10.0.0.11 \
#     --syslog-host  10.20.30.200 \
#     --pubkey       "ssh-ed25519 AAAA... analyst@workstation" \
#     --variant      basic
#
# Required environment variables:
#   GOVC_URL       — vCenter FQDN
#   GOVC_USERNAME  — vCenter service account
#   GOVC_PASSWORD  — vCenter password
#   GOVC_INSECURE  — true|false

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
VARIANT="basic"
EXPIRY_DATE=$(date -d '+30 days' +%Y-%m-%d)
DNS_SEARCH="your.domain.local"
CONTENT_LIBRARY="${CONTENT_LIBRARY:-kali-templates}"
DATASTORE="${DATASTORE:-DS-Pentest-01}"
VCENTER_FOLDER="${VCENTER_FOLDER:-/DC/vm/pentest}"

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --zone)         ZONE="$2";         shift 2 ;;
    --request-id)   REQUEST_ID="$2";   shift 2 ;;
    --requester)    REQUESTER="$2";    shift 2 ;;
    --static-ip)    STATIC_IP="$2";    shift 2 ;;
    --prefix)       PREFIX="$2";       shift 2 ;;
    --gateway)      GATEWAY="$2";      shift 2 ;;
    --dns1)         DNS1="$2";         shift 2 ;;
    --dns2)         DNS2="$2";         shift 2 ;;
    --syslog-host)  SYSLOG_HOST="$2";  shift 2 ;;
    --pubkey)       PUBKEY="$2";       shift 2 ;;
    --variant)      VARIANT="$2";      shift 2 ;;
    --expiry)       EXPIRY_DATE="$2";  shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

# ── Validate required arguments ───────────────────────────────────────────────
REQUIRED=(ZONE REQUEST_ID REQUESTER STATIC_IP PREFIX GATEWAY DNS1 DNS2 SYSLOG_HOST PUBKEY)
for var in "${REQUIRED[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: --${var,,} is required"
    exit 1
  fi
done

# ── Derived values ────────────────────────────────────────────────────────────
HOSTNAME="kali-${ZONE,,}-${REQUEST_ID,,}"
HOSTNAME="${HOSTNAME:0:63}"    # hostname max length
VM_NAME="KaliVM-${ZONE}-${REQUEST_ID}"
WEEK_TAG=$(date +%G-W%V)

if [ "$VARIANT" = "custom" ]; then
  TEMPLATE_NAME="kali-soc-custom-${WEEK_TAG}"
else
  TEMPLATE_NAME="kali-basic-${WEEK_TAG}"
fi

echo "================================================"
echo " Deploying Kali VM"
echo "================================================"
echo "  VM name     : $VM_NAME"
echo "  Template    : $TEMPLATE_NAME"
echo "  Zone        : $ZONE"
echo "  Request     : $REQUEST_ID"
echo "  Requester   : $REQUESTER"
echo "  IP          : $STATIC_IP/$PREFIX"
echo "  Expiry      : $EXPIRY_DATE"
echo "================================================"

# ── Step 1: Clone template ────────────────────────────────────────────────────
echo "[1/5] Cloning template..."
govc vm.clone \
  -vm="${TEMPLATE_NAME}" \
  -folder="${VCENTER_FOLDER}/${ZONE}" \
  -datastore="${DATASTORE}" \
  -name="${VM_NAME}" \
  -on=false

echo "VM cloned: $VM_NAME"

# ── Step 2: Render and inject cloud-init metadata ─────────────────────────────
echo "[2/5] Injecting cloud-init configuration..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Render metadata template
METADATA=$(sed \
  -e "s|\${VM_NAME}|$VM_NAME|g" \
  -e "s|\${HOSTNAME}|$HOSTNAME|g" \
  -e "s|\${STATIC_IP}|$STATIC_IP|g" \
  -e "s|\${PREFIX_LENGTH}|$PREFIX|g" \
  -e "s|\${GATEWAY}|$GATEWAY|g" \
  -e "s|\${DNS1}|$DNS1|g" \
  -e "s|\${DNS2}|$DNS2|g" \
  -e "s|\${DNS_SEARCH}|$DNS_SEARCH|g" \
  "$SCRIPT_DIR/cloud-init/metadata.yaml.tpl")

# Render userdata template
USERDATA=$(sed \
  -e "s|\${ANALYST_SSH_PUBKEY}|$PUBKEY|g" \
  -e "s|\${HOSTNAME}|$HOSTNAME|g" \
  -e "s|\${SYSLOG_HOST}|$SYSLOG_HOST|g" \
  -e "s|\${REQUEST_ID}|$REQUEST_ID|g" \
  -e "s|\${ZONE}|$ZONE|g" \
  -e "s|\${EXPIRY_DATE}|$EXPIRY_DATE|g" \
  -e "s|\${REQUESTER}|$REQUESTER|g" \
  "$SCRIPT_DIR/cloud-init/userdata.yaml.tpl")

# Inject via GuestInfo
govc vm.change -vm="${VM_NAME}" \
  -e "guestinfo.metadata=$(echo "$METADATA" | base64 -w0)" \
  -e "guestinfo.metadata.encoding=base64" \
  -e "guestinfo.userdata=$(echo "$USERDATA" | base64 -w0)" \
  -e "guestinfo.userdata.encoding=base64"

echo "GuestInfo injected"

# ── Step 3: Set audit custom attributes ───────────────────────────────────────
echo "[3/5] Setting vSphere custom attributes..."

# Create attributes if they don't exist (idempotent)
for attr in Requester Zone RequestID ExpiryDate; do
  govc fields.add "$attr" VirtualMachine 2>/dev/null || true
done

govc fields.set "Requester"  "$REQUESTER"   "$VM_NAME"
govc fields.set "Zone"       "$ZONE"        "$VM_NAME"
govc fields.set "RequestID"  "$REQUEST_ID"  "$VM_NAME"
govc fields.set "ExpiryDate" "$EXPIRY_DATE" "$VM_NAME"

echo "Custom attributes set"

# ── Step 4: Power on ──────────────────────────────────────────────────────────
echo "[4/5] Powering on VM..."
govc vm.power -on "${VM_NAME}"
echo "VM powered on — cloud-init will configure on first boot"

# ── Step 5: Wait for VM to come up ───────────────────────────────────────────
echo "[5/5] Waiting for VM IP to be reported by VMware Tools..."
for i in $(seq 1 30); do
  sleep 10
  REPORTED_IP=$(govc vm.ip "${VM_NAME}" 2>/dev/null || true)
  if [ -n "$REPORTED_IP" ]; then
    echo "VM is up — reported IP: $REPORTED_IP"
    break
  fi
  echo "Attempt $i/30 — VM not yet reachable..."
  [ $i -eq 30 ] && echo "WARNING: VM did not report IP within 5 minutes" && break
done

echo "================================================"
echo " Deployment complete"
echo "  VM name  : $VM_NAME"
echo "  IP       : $STATIC_IP"
echo "  Hostname : $HOSTNAME"
echo "  Expiry   : $EXPIRY_DATE"
echo "================================================"
