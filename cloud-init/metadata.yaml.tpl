# cloud-init/metadata.yaml.tpl
# Template for cloud-init metadata — rendered per VM at deploy time.
# Replace all ${PLACEHOLDER} values using govc or Terraform before injection.
#
# Rendered file is base64-encoded and injected via:
#   govc vm.change -e guestinfo.metadata="$(base64 -w0 rendered-metadata.yaml)"
#   govc vm.change -e guestinfo.metadata.encoding="base64"
#
# Variables to substitute:
#   ${VM_NAME}        — e.g. KaliVM-ZD-XXX-001-REQ001
#   ${HOSTNAME}       — short hostname, e.g. kali-zd-001
#   ${STATIC_IP}      — e.g. 10.20.30.100
#   ${PREFIX_LENGTH}  — e.g. 24
#   ${GATEWAY}        — e.g. 10.20.30.1
#   ${DNS1}           — e.g. 10.0.0.10
#   ${DNS2}           — e.g. 10.0.0.11
#   ${DNS_SEARCH}     — e.g. your.domain.local

instance-id: ${VM_NAME}
local-hostname: ${HOSTNAME}

network:
  version: 2
  ethernets:
    ens192:
      addresses:
        - ${STATIC_IP}/${PREFIX_LENGTH}
      gateway4: ${GATEWAY}
      nameservers:
        addresses:
          - ${DNS1}
          - ${DNS2}
        search:
          - ${DNS_SEARCH}
