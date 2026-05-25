# kali-soc-packer

Automated weekly build pipeline for Kali Linux pentest VM templates on VMware vSphere.
Builds two variants from the official Kali vendor ISO: a basic variant and a custom SOC variant with a full offensive security toolset.

## How it works

Every Monday at 02:00 UTC, the GitHub Actions pipeline:

1. Downloads the latest Kali Linux installer ISO from kali.org
2. Verifies the SHA256 checksum and PGP signature
3. Runs Packer to build a VM from the ISO (unattended via preseed.cfg)
4. Installs open-vm-tools, perl, cloud-init and rsyslog inside the VM
5. Seals the template (removes SSH host keys, clears logs, zeros free space)
6. Publishes the OVA to the vSphere Content Library
7. Runs a smoke test (boot, SSH reachability, key package checks)
8. Promotes the template and rotates old builds (keeps last 2)

Deployed VMs are configured at first boot via cloud-init using VMware GuestInfo properties injected by `deploy-vm.sh`.

## Repository structure

```
.github/workflows/kali-build.yml   GitHub Actions pipeline
kali-basic.pkr.hcl                 Packer build — basic variant
kali-custom.pkr.hcl                Packer build — custom SOC variant
versions.pkr.hcl                   Packer version and plugin requirements
variables.pkr.hcl                  All variable declarations
variables/basic.pkrvars.hcl        Basic variant values (2 CPU, 4GB, 40GB)
variables/custom.pkrvars.hcl       Custom variant values (4 CPU, 8GB, 80GB)
http/preseed.cfg                   Debian preseed for unattended install
scripts/01-base.sh                 Base provisioner (open-vm-tools, cloud-init)
scripts/02-soc-tools.sh            SOC toolset provisioner (custom only)
scripts/99-cleanup.sh              Template sealing
ansible/soc-tools.yml              Ansible playbook defining SOC toolset
cloud-init/99-vmware.cfg           cloud-init datasource config (baked in)
cloud-init/metadata.yaml.tpl       Network config template (rendered per VM)
cloud-init/userdata.yaml.tpl       First-boot config template (rendered per VM)
deploy-vm.sh                       Deploy a VM from template
destroy-vm.sh                      Destroy a VM or sweep expired VMs
setup-runner.sh                    Install and register the GitHub Actions runner
```

## Prerequisites

### GitHub repository secrets

| Secret | Description |
|---|---|
| `VCENTER_PASS` | vCenter service account password |
| `BUILD_SSH_PASS` | Temporary password Packer uses during build |
| `SMOKE_SSH_KEY` | Private SSH key for smoke test access |
| `SLACK_WEBHOOK` | Slack webhook URL for failure alerts (optional) |

### GitHub repository variables

| Variable | Example |
|---|---|
| `VCENTER_HOST` | `vcenter.your.domain` |
| `VCENTER_USER` | `svc-packer@vsphere.local` |
| `DATACENTER` | `DC-01` |
| `CLUSTER` | `Cluster-01` |
| `DATASTORE` | `DS-Pentest-01` |
| `BUILD_NETWORK` | `VM Network` |
| `CONTENT_LIBRARY` | `kali-templates` |
| `SMOKE_FOLDER` | `/DC-01/vm/smoke-test` |
| `SMOKE_HOST` | `esxi01.your.domain` |
| `SMOKE_IP` | `10.10.20.50` |

### Self-hosted runner

The pipeline requires a self-hosted runner with network access to kali.org and your vCenter.

```bash
# Install runner, Packer, and govc:
sudo bash setup-runner.sh \
  --repo  https://github.com/your-org/kali-soc-packer \
  --token YOUR_REGISTRATION_TOKEN
```

Get the registration token from:
**Your repo → Settings → Actions → Runners → New self-hosted runner**

## Running the pipeline

**Automatic:** fires every Monday at 02:00 UTC.

**Manual:** go to **Actions → Kali VM weekly build → Run workflow**.
Choose variant: `both` (default), `basic`, or `custom`.

## Deploying a VM

After the pipeline succeeds and a template exists in the Content Library:

```bash
export GOVC_URL=vcenter.your.domain
export GOVC_USERNAME=svc-packer@vsphere.local
export GOVC_PASSWORD=your-password
export GOVC_INSECURE=false

./deploy-vm.sh \
  --zone        ZD-XXX-001 \
  --request-id  REQ-20260525-001 \
  --requester   "j.doe" \
  --static-ip   10.20.30.100 \
  --prefix      24 \
  --gateway     10.20.30.1 \
  --dns1        10.0.0.10 \
  --dns2        10.0.0.11 \
  --syslog-host 10.20.30.200 \
  --pubkey      "ssh-ed25519 AAAA... analyst@workstation" \
  --variant     basic
```

## Destroying expired VMs

```bash
# Destroy a specific VM:
./destroy-vm.sh --vm-name "KaliVM-ZD-XXX-001-REQ001"

# Sweep all VMs past their expiry date (for cron):
./destroy-vm.sh --expired
```

Add to cron on a management host for automatic lifecycle enforcement:

```cron
0 6 * * * GOVC_URL=... GOVC_USERNAME=... GOVC_PASSWORD=... /opt/kali-soc-packer/destroy-vm.sh --expired
```

## Customising the SOC toolset

Edit `ansible/soc-tools.yml` to add or remove tools from the custom variant.
The playbook is self-documenting — tools are grouped by category with comments.

## Security notes

- Sensitive values (vCenter password, build SSH password) are stored as GitHub Secrets — never in the repository
- The preseed.cfg contains a placeholder password that is replaced before the template is sealed
- SSH host keys are removed by 99-cleanup.sh — new keys are generated on each VM's first boot
- All deployed VMs carry vSphere custom attributes (Requester, Zone, RequestID, ExpiryDate) for audit traceability
