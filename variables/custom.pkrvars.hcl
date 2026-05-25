# variables/custom.pkrvars.hcl
# Variable values for the custom SOC Kali variant.
# Sensitive values (vcenter_pass, build_ssh_pass) are passed via
# -var flags from the GitHub Actions workflow — never stored here.

vm_name_prefix  = "kali-soc-custom"
cpu_count       = 4
ram_mb          = 8192
disk_gb         = 80
extra_scripts   = ["scripts/02-soc-tools.sh"]
