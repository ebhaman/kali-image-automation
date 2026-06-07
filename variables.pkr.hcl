# ── vSphere connection ────────────────────────────────────────────────────────
# ── vSphere connection ────────────────────────────────────────────────────────
variable "vcenter_host" {
  description = "vCenter server FQDN or IP"
  type        = string
}

variable "vcenter_user" {
  description = "vCenter service account username"
  type        = string
}

variable "vcenter_pass" {
  description = "vCenter service account password"
  type        = string
  sensitive   = true
}

variable "datacenter" {
  description = "vSphere datacenter name"
  type        = string
}

variable "cluster" {
  description = "vSphere cluster name"
  type        = string
}

variable "datastore" {
  description = "vSphere datastore name"
  type        = string
}

variable "build_network" {
  description = "vSphere network/portgroup used during the Packer build"
  type        = string
}

variable "content_library" {
  description = "vSphere content library name where templates are published"
  type        = string
}

# ── ISO ───────────────────────────────────────────────────────────────────────
variable "kali_iso_url" {
  description = "Full path or URL to the Kali installer ISO"
  type        = string
}

variable "kali_iso_sha256" {
  description = "SHA256 checksum of the ISO (without 'sha256:' prefix)"
  type        = string
}

# ── Build credentials ─────────────────────────────────────────────────────────
variable "build_ssh_pass" {
  description = "Temporary password used by Packer to SSH into the VM during build"
  type        = string
  sensitive   = true
}

# ── VM sizing (overridden per variant in pkrvars files) ───────────────────────
variable "vm_name_prefix" {
  description = "Prefix for the template name — week number is appended"
  type        = string
  default     = "kali-basic"
}

variable "cpu_count" {
  description = "Number of vCPUs"
  type        = number
  default     = 2
}

variable "ram_mb" {
  description = "RAM in megabytes"
  type        = number
  default     = 4096
}

variable "disk_gb" {
  description = "Primary disk size in gigabytes"
  type        = number
  default     = 40
}

# ── VM sizing (overridden per variant in pkrvars files) ───────────────────────
variable "vm_name_prefix" {
  description = "Prefix for the template name — week number is appended"
  type        = string
  default     = "kali-basic"
}

variable "cpu_count" {
  description = "Number of vCPUs"
  type        = number
  default     = 2
}

variable "ram_mb" {
  description = "RAM in megabytes"
  type        = number
  default     = 4096
}

variable "disk_gb" {
  description = "Primary disk size in gigabytes"
  type        = number
  default     = 40
}

