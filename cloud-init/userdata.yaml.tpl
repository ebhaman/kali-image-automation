# cloud-init/userdata.yaml.tpl
# Template for cloud-init userdata — rendered per VM at deploy time.
# Replace all ${PLACEHOLDER} values using govc or Terraform before injection.
#
# Rendered file is base64-encoded and injected via:
#   govc vm.change -e guestinfo.userdata="$(base64 -w0 rendered-userdata.yaml)"
#   govc vm.change -e guestinfo.userdata.encoding="base64"
#
# Variables to substitute:
#   ${ANALYST_SSH_PUBKEY}  — analyst's SSH public key (full line, e.g. ssh-ed25519 AAAA... user@host)
#   ${HOSTNAME}            — short hostname
#   ${SYSLOG_HOST}         — IP of zone syslog VM (replaces SYSLOG_PLACEHOLDER in rsyslog config)
#   ${REQUEST_ID}          — Snow Commander request ID for audit trail
#   ${ZONE}                — target network zone (e.g. ZD-XXX-001)
#   ${EXPIRY_DATE}         — VM expiry date (e.g. 2026-06-25)
#   ${REQUESTER}           — name or username of the requester

#cloud-config

# ── User account ──────────────────────────────────────────────────────────────
users:
  - name: analyst
    gecos: Pentest Analyst
    groups: sudo
    shell: /bin/bash
    lock_passwd: true            # password login disabled — SSH key only
    ssh_authorized_keys:
      - ${ANALYST_SSH_PUBKEY}

# ── First-boot commands ───────────────────────────────────────────────────────
runcmd:
  # Set hostname
  - hostnamectl set-hostname ${HOSTNAME}

  # Enable and start SSH
  - systemctl enable --now ssh

  # Inject zone syslog endpoint into rsyslog config
  - sed -i 's/SYSLOG_PLACEHOLDER/${SYSLOG_HOST}/g' /etc/rsyslog.d/10-remote.conf
  - systemctl restart rsyslog

  # Disable password authentication for SSH (key-only)
  - sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  - sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  - systemctl restart ssh

  # Prevent cloud-init from running again on subsequent boots
  - cloud-init clean --logs
  - touch /etc/cloud/cloud-init.disabled

# ── Write MOTD with scope reminder ────────────────────────────────────────────
write_files:
  - path: /etc/motd
    owner: root:root
    permissions: '0644'
    content: |
      ╔══════════════════════════════════════════════════════════════╗
      ║              KALI LINUX PENTEST VM — RESTRICTED              ║
      ╠══════════════════════════════════════════════════════════════╣
      ║  Zone     : ${ZONE}
      ║  Request  : ${REQUEST_ID}
      ║  Requester: ${REQUESTER}
      ║  Expires  : ${EXPIRY_DATE}
      ╠══════════════════════════════════════════════════════════════╣
      ║  ALL ACTIVITY ON THIS SYSTEM IS MONITORED AND LOGGED.        ║
      ║  Unauthorised access is prohibited.                          ║
      ║  Use is restricted to the approved scope only.               ║
      ╚══════════════════════════════════════════════════════════════╝

  # Audit marker — readable by CSI for post-test review
  - path: /etc/kali-vm-metadata
    owner: root:root
    permissions: '0644'
    content: |
      request_id=${REQUEST_ID}
      zone=${ZONE}
      requester=${REQUESTER}
      expiry=${EXPIRY_DATE}
      hostname=${HOSTNAME}
