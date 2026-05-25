#!/bin/bash
# setup-runner.sh
# Installs and registers a GitHub Actions self-hosted runner with all
# dependencies needed for the Kali VM build pipeline.
#
# Run this on the machine that will be your build runner.
# The runner needs network access to:
#   - github.com (runner registration and job dispatch)
#   - cdimage.kali.org (ISO download)
#   - your vCenter (Packer vsphere-iso builder)
#
# Usage:
#   sudo bash setup-runner.sh \
#     --repo   https://github.com/your-org/kali-soc-packer \
#     --token  YOUR_REGISTRATION_TOKEN
#
# Get the token from:
#   Your repo → Settings → Actions → Runners → New self-hosted runner
#
# NOTE: Run as root or with sudo. The runner service itself runs as the
#       'actions-runner' user created by this script.

set -euo pipefail

RUNNER_USER="actions-runner"
RUNNER_DIR="/home/${RUNNER_USER}/actions-runner"
RUNNER_LABELS="packer,vsphere"

REPO_URL=""
TOKEN=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --repo)  REPO_URL="$2"; shift 2 ;;
    --token) TOKEN="$2";    shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if [ -z "$REPO_URL" ] || [ -z "$TOKEN" ]; then
  echo "Usage: $0 --repo <github-repo-url> --token <registration-token>"
  exit 1
fi

echo "================================================"
echo " GitHub Actions runner setup"
echo "================================================"

# ── System dependencies ───────────────────────────────────────────────────────
echo "[1/6] Installing system dependencies..."
apt-get update -qq
apt-get install -y -qq \
  curl wget git jq gnupg \
  ca-certificates apt-transport-https \
  software-properties-common \
  python3 python3-pip ansible

# ── HashiCorp Packer ──────────────────────────────────────────────────────────
echo "[2/6] Installing Packer..."
if ! command -v packer &>/dev/null; then
  wget -O- https://apt.releases.hashicorp.com/gpg \
    | gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    | tee /etc/apt/sources.list.d/hashicorp.list
  apt-get update -qq
  apt-get install -y packer
fi
packer version

# ── govc (VMware CLI) ─────────────────────────────────────────────────────────
echo "[3/6] Installing govc..."
if ! command -v govc &>/dev/null; then
  GOVC_VERSION=$(curl -s https://api.github.com/repos/vmware/govmomi/releases/latest \
    | jq -r '.tag_name' | sed 's/v//')
  curl -L "https://github.com/vmware/govmomi/releases/download/v${GOVC_VERSION}/govc_Linux_x86_64.tar.gz" \
    | tar -C /usr/local/bin -xzf - govc
  chmod +x /usr/local/bin/govc
fi
govc version

# ── Runner user ───────────────────────────────────────────────────────────────
echo "[4/6] Creating runner user..."
if ! id "$RUNNER_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$RUNNER_USER"
fi
mkdir -p "$RUNNER_DIR"
chown -R "${RUNNER_USER}:${RUNNER_USER}" "$RUNNER_DIR"

# ── Download runner (latest version for this org) ──────────────────────────────
echo "[5/6] Downloading GitHub Actions runner..."

# Get latest available runner version
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest \
  | jq -r '.tag_name' | sed 's/v//')

echo "Latest runner version: ${RUNNER_VERSION}"

su - "$RUNNER_USER" -c "
  cd ${RUNNER_DIR}

  # Download
  curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \
    https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

  # Extract
  tar xzf actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
  rm actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
"

# ── Register ──────────────────────────────────────────────────────────────────
echo "[6/6] Registering runner with GitHub..."

su - "$RUNNER_USER" -c "
  cd ${RUNNER_DIR}
  ./config.sh \
    --url ${REPO_URL} \
    --token ${TOKEN} \
    --name kali-packer-runner \
    --labels ${RUNNER_LABELS} \
    --unattended \
    --replace
"

# Install and start as a system service
cd "$RUNNER_DIR"
./svc.sh install "$RUNNER_USER"
./svc.sh start

echo ""
echo "================================================"
echo " Runner installed and running"
echo "  User    : $RUNNER_USER"
echo "  Dir     : $RUNNER_DIR"
echo "  Labels  : $RUNNER_LABELS"
echo "  Version : $RUNNER_VERSION"
echo ""
echo " Check status:  sudo ${RUNNER_DIR}/svc.sh status"
echo " View logs:     sudo journalctl -u actions.runner.* -f"
echo "================================================"
