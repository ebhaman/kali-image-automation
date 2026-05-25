locals {
  # Template name includes ISO week number — e.g. kali-basic-2026-W21
  template_name = "${var.vm_name_prefix}-${formatdate("YYYY", timestamp())}-W${formatdate("WW", timestamp())}"
  build_scripts = concat(["scripts/01-base.sh"], var.extra_scripts, ["scripts/99-cleanup.sh"])
}

# ── Source: vsphere-iso ───────────────────────────────────────────────────────
source "vsphere-iso" "kali" {
  # Connection
  vcenter_server      = var.vcenter_host
  username            = var.vcenter_user
  password            = var.vcenter_pass
  insecure_connection = false

  # Placement
  datacenter = var.datacenter
  cluster    = var.cluster
  datastore  = var.datastore
  folder     = "templates/kali"

  # VM identity
  # guest_os_type must be debian-based for vSphere to recognise open-vm-tools
  vm_name       = local.template_name
  guest_os_type = "debian12_64Guest"
  notes         = "Built by Packer on ${formatdate("YYYY-MM-DD", timestamp())} — kali-soc-packer pipeline"

  # Hardware
  CPUs                 = var.cpu_count
  RAM                  = var.ram_mb
  RAM_reserve_all      = false
  disk_controller_type = ["pvscsi"]

  storage {
    disk_size             = var.disk_gb * 1024   # convert GB to MB
    disk_thin_provisioned = true
  }

  network_adapters {
    network      = var.build_network
    network_card = "vmxnet3"
  }

  # ISO
  iso_url      = var.kali_iso_url
  iso_checksum = "sha256:${var.kali_iso_sha256}"

  # Unattended install — preseed.cfg is served via Packer's built-in HTTP server
  http_directory = "http"
  boot_wait      = "5s"
  boot_command = [
    "<esc><wait>",
    "auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "hostname=kali-template ",
    "domain=local ",
    "<enter>"
  ]

  # SSH communicator — Packer connects after install to run provisioners
  communicator     = "ssh"
  ssh_username     = "kali"
  ssh_password     = var.build_ssh_pass
  ssh_timeout      = "30m"
  ssh_handshake_attempts = 20

  # Shutdown
  shutdown_command = "echo '${var.build_ssh_pass}' | sudo -S shutdown -h now"
  shutdown_timeout = "10m"

  # Publish as template to vSphere Content Library
  convert_to_template = false        # content_library_destination handles this

  content_library_destination {
    library     = var.content_library
    name        = local.template_name
    description = "Kali Linux pentest VM — built ${formatdate("YYYY-MM-DD", timestamp())}"
    ovf         = true
    destroy     = true               # destroy the VM after publishing to library
  }
}

# ── Build ─────────────────────────────────────────────────────────────────────
build {
  name    = "kali-basic"
  sources = ["source.vsphere-iso.kali"]

  # Step 1: base packages — open-vm-tools, perl, cloud-init, rsyslog
  provisioner "shell" {
    script          = "scripts/01-base.sh"
    execute_command = "echo '${var.build_ssh_pass}' | sudo -S bash {{.Path}}"
  }

  # Step 2: optional extra scripts (e.g. SOC toolset for custom variant)
  dynamic "provisioner" {
    labels   = ["shell"]
    for_each = var.extra_scripts
    content {
      script          = provisioner.value
      execute_command = "echo '${var.build_ssh_pass}' | sudo -S bash {{.Path}}"
    }
  }

  # Step 3: drop cloud-init datasource config
  provisioner "file" {
    source      = "cloud-init/99-vmware.cfg"
    destination = "/tmp/99-vmware.cfg"
  }

  provisioner "shell" {
    inline = [
      "echo '${var.build_ssh_pass}' | sudo -S cp /tmp/99-vmware.cfg /etc/cloud/cloud.cfg.d/99-vmware.cfg",
      "sudo chown root:root /etc/cloud/cloud.cfg.d/99-vmware.cfg",
      "sudo chmod 644 /etc/cloud/cloud.cfg.d/99-vmware.cfg"
    ]
  }

  # Step 4: seal — remove SSH host keys, clear logs, zero free space
  provisioner "shell" {
    script          = "scripts/99-cleanup.sh"
    execute_command = "echo '${var.build_ssh_pass}' | sudo -S bash {{.Path}}"
  }
}
