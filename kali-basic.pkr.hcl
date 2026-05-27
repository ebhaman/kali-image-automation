locals {
  template_name = "kali-basic-${formatdate("YYYY", timestamp())}-W${formatdate("WW", timestamp())}"
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
  vm_name       = local.template_name
  guest_os_type = "debian12_64Guest"
  notes         = "Built by Packer on ${formatdate("YYYY-MM-DD", timestamp())} — kali-basic"

  # Hardware
  CPUs                 = var.cpu_count
  RAM                  = var.ram_mb
  RAM_reserve_all      = false
  disk_controller_type = ["pvscsi"]

  storage {
    disk_size             = var.disk_gb * 1024
    disk_thin_provisioned = true
  }

  network_adapters {
    network      = var.build_network
    network_card = "vmxnet3"
  }

  # ISO
  iso_url      = var.kali_iso_url
  iso_checksum = "sha256:${var.kali_iso_sha256}"

  # Unattended install
  http_directory = "http"
  boot_wait      = "5s"
  boot_command = [
    "<esc><wait>",
    "auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "hostname=kali-template domain=local ",
    "<enter>"
  ]

  # SSH communicator
  communicator           = "ssh"
  ssh_username           = "kali"
  ssh_password           = var.build_ssh_pass
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 20

  # Shutdown
  shutdown_command = "echo '${var.build_ssh_pass}' | sudo -S shutdown -h now"
  shutdown_timeout = "10m"

  # Publish to content library
  convert_to_template = false

  content_library_destination {
    library     = var.content_library
    name        = local.template_name
    description = "Kali Linux basic VM — built ${formatdate("YYYY-MM-DD", timestamp())}"
    ovf         = true
    destroy     = true
  }
}

# ── Build ─────────────────────────────────────────────────────────────────────
build {
  name    = "kali-basic"
  sources = ["source.vsphere-iso.kali"]

  # Step 1: base packages
  provisioner "shell" {
    script          = "scripts/01-base.sh"
    execute_command = "echo '${var.build_ssh_pass}' | sudo -S bash {{.Path}}"
  }

  # Step 2: cloud-init datasource config
  provisioner "file" {
    source      = "cloud-init/99-vmware.cfg"
    destination = "/tmp/99-vmware.cfg"
  }

  provisioner "shell" {
    inline = [
      "sudo cp /tmp/99-vmware.cfg /etc/cloud/cloud.cfg.d/99-vmware.cfg",
      "sudo chown root:root /etc/cloud/cloud.cfg.d/99-vmware.cfg",
      "sudo chmod 644 /etc/cloud/cloud.cfg.d/99-vmware.cfg"
    ]
    execute_command = "echo '${var.build_ssh_pass}' | sudo -S bash -c '{{.Command}}'"
  }

  # Step 3: seal template
  provisioner "shell" {
    script          = "scripts/99-cleanup.sh"
    execute_command = "echo '${var.build_ssh_pass}' | sudo -S bash {{.Path}}"
  }
}
