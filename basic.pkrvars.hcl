# variables/basic.pkrvars.hcl
# Variable values for the basic Kali variant.
# Sensitive values (vcenter_pass, build_ssh_pass) are passed via
# -var flags from the GitHub Actions workflow — never stored here.

vm_name_prefix  = "kali-basic"
cpu_count       = 2
ram_mb          = 4096
disk_gb         = 40
