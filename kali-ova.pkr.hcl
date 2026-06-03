locals {
  ova_name = "kali-ova-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
}

source "vmware-iso" "kali-ova" {
  vm_name       = local.ova_name
  guest_os_type = "debian12-64"

  # Memory & CPU
  cores  = var.cpu_count
  memory = var.ram_mb

  # Disk configuration
  disk_size             = var.disk_gb * 1024
  disk_adapter_type     = "pvscsi"
  disk_type_id          = "thin"
  disk_controller_count = 1

  # Network — use NAT for builds without vCenter
  network_adapter_type = "vmxnet3"

  # ISO source
  iso_url      = var.kali_iso_url
  iso_checksum = "sha256:${var.kali_iso_sha256}"

  # Unattended install via preseed
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
  ssh_timeout            = "45m"
  ssh_handshake_attempts = 20

  # Output configuration — generate OVA
  output_directory = "output-ova"
  format           = "ova"

  # Optional: create ovftool-compatible export descriptor
  ovftool_options = [
    "--loglevel=verbose",
    "--exportFlags=noImageFiles"
  ]

  # Shutdown
  shutdown_command = "echo '${var.build_ssh_pass}' | sudo -S shutdown -h now"
  shutdown_timeout = "10m"

  # vSphere VM Tools
  tools_upload_flavor = "linux"
  tools_iso_path      = "[${var.datastore}] ISO/linux.iso"

  # Optional: SSH key-based auth for faster builds
  skip_compaction = false
  keep_registered = false
}

build {
  name    = "kali-ova"
  sources = ["source.vmware-iso.kali-ova"]

  # Step 1: base packages
  provisioner "shell" {
    script          = "scripts/01-base.sh"
    execute_command = "echo '${var.build_ssh_pass}' | sudo -S bash {{.Path}}"
  }

  # Step 2: SOC toolset (optional)
  provisioner "shell" {
    script          = "scripts/02-soc-tools.sh"
    execute_command = "echo '${var.build_ssh_pass}' | sudo -S bash {{.Path}}"
    only            = ["vmware-iso.kali-ova"]
  }

  # Step 3: cloud-init datasource config
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

  # Step 4: seal template
  provisioner "shell" {
    script          = "scripts/99-cleanup.sh"
    execute_command = "echo '${var.build_ssh_pass}' | sudo -S bash {{.Path}}"
  }

  # Step 5: generate manifest
  provisioner "shell" {
    inline = [
      "echo 'OVA built on $(date -u +%Y-%m-%dT%H:%M:%SZ)' > /tmp/ova-manifest.txt",
      "echo 'Hostname: kali-template' >> /tmp/ova-manifest.txt",
      "echo 'vCPUs: ${var.cpu_count}' >> /tmp/ova-manifest.txt",
      "echo 'RAM: ${var.ram_mb}MB' >> /tmp/ova-manifest.txt",
      "echo 'Disk: ${var.disk_gb}GB' >> /tmp/ova-manifest.txt"
    ]
  }
}
