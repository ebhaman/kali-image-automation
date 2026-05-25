locals {
  custom_template_name = "${var.vm_name_prefix}-${formatdate("YYYY", timestamp())}-W${formatdate("WW", timestamp())}"
  custom_build_scripts = concat(["scripts/01-base.sh"], var.extra_scripts, ["scripts/99-cleanup.sh"])
}

source "vsphere-iso" "kali-custom" {
  vcenter_server      = var.vcenter_host
  username            = var.vcenter_user
  password            = var.vcenter_pass
  insecure_connection = false

  datacenter = var.datacenter
  cluster    = var.cluster
  datastore  = var.datastore
  folder     = "templates/kali"

  vm_name       = local.custom_template_name
  guest_os_type = "debian12_64Guest"
  notes         = "Built by Packer on ${formatdate("YYYY-MM-DD", timestamp())} — kali-soc-packer pipeline (custom SOC variant)"

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

  iso_url      = var.kali_iso_url
  iso_checksum = "sha256:${var.kali_iso_sha256}"

  http_directory = "http"
  boot_wait      = "5s"
  boot_command = [
    "<esc><wait>",
    "auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "hostname=kali-template ",
    "domain=local ",
    "<enter>"
  ]

  communicator           = "ssh"
  ssh_username           = "kali"
  ssh_password           = var.build_ssh_pass
  ssh_timeout            = "45m"
  ssh_handshake_attempts = 20

  shutdown_command = "echo '${var.build_ssh_pass}' | sudo -S shutdown -h now"
  shutdown_timeout = "10m"

  convert_to_template = false

  content_library_destination {
    library     = var.content_library
    name        = local.custom_template_name
    description = "Kali Linux SOC custom VM — built ${formatdate("YYYY-MM-DD", timestamp())}"
    ovf         = true
    destroy     = true
  }
}

build {
  name    = "kali-custom"
  sources = ["source.vsphere-iso.kali-custom"]

  provisioner "shell" {
    script          = "scripts/01-base.sh"
    execute_command = "echo '${var.build_ssh_pass}' | sudo -S bash {{.Path}}"
  }

  # SOC toolset via Ansible
  provisioner "shell" {
    script          = "scripts/02-soc-tools.sh"
    execute_command = "echo '${var.build_ssh_pass}' | sudo -S bash {{.Path}}"
  }

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

  provisioner "shell" {
    script          = "scripts/99-cleanup.sh"
    execute_command = "echo '${var.build_ssh_pass}' | sudo -S bash {{.Path}}"
  }
}
