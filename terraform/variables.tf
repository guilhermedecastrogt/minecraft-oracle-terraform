variable "tenancy_ocid" {
  description = "OCID of the Oracle Cloud tenancy (root account)."
  type        = string
}

variable "user_ocid" {
  description = "OCID of the user that owns the API key."
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of the API key registered in the OCI console."
  type        = string
}

variable "private_key_path" {
  description = "Local path to the API key's .pem private key."
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "region" {
  description = "OCI region to deploy into. Always Free only works in the tenancy home region."
  type        = string
  default     = "sa-saopaulo-1"
}

variable "compartment_ocid" {
  description = "Compartment OCID. Leave empty to use the tenancy root."
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "Contents of the SSH public key granted access to the VM."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR range allowed to reach SSH. Prefer YOUR_IP/32 over 0.0.0.0/0."
  type        = string
  default     = "0.0.0.0/0"
}

variable "instance_name" {
  description = "VM display name in the Oracle console."
  type        = string
  default     = "pterodactyl"
}

variable "instance_ocpus" {
  description = "ARM cores (Ampere A1). Always Free cap: 4."
  type        = number
  default     = 2
}

variable "instance_memory_gb" {
  description = "Memory in GB. Always Free cap: 24. The panel stack itself needs about 1.5."
  type        = number
  default     = 12
}

variable "boot_volume_gb" {
  description = "Disk size in GB. Always Free grants 200 GB total; minimum per VM is 50."
  type        = number
  default     = 100
}

variable "ubuntu_version" {
  description = "Ubuntu release used as the base image."
  type        = string
  default     = "24.04"
}

variable "availability_domain_index" {
  description = "Availability domain to use (0, 1, 2...). Only meaningful in multi-AD regions."
  type        = number
  default     = 0
}

variable "timezone" {
  description = "Timezone used by the panel and the game containers."
  type        = string
  default     = "America/Sao_Paulo"
}

variable "panel_domain" {
  description = <<-EOT
    Domain pointing at the VM, without subdomain (e.g. example.com). The panel is
    served at panel.<domain> and the daemon at node.<domain>. Leave empty to use
    sslip.io, which resolves any <ip>-based name straight to the instance IP and
    needs no DNS setup at all.
  EOT
  type        = string
  default     = ""
}

variable "panel_admin_email" {
  description = "Email of the panel's first admin user. Also used for Let's Encrypt."
  type        = string
}

variable "panel_admin_username" {
  description = "Username of the panel's first admin user."
  type        = string
  default     = "admin"
}

variable "panel_admin_first_name" {
  description = "First name of the panel's first admin user."
  type        = string
  default     = "Server"
}

variable "panel_admin_last_name" {
  description = "Last name of the panel's first admin user."
  type        = string
  default     = "Admin"
}

variable "panel_admin_password" {
  description = "Password of the panel's first admin user. Empty generates a strong one."
  type        = string
  default     = ""
  sensitive   = true
}

variable "game_port_min" {
  description = "First port of the range Wings hands out to game servers."
  type        = number
  default     = 25565
}

variable "game_port_max" {
  description = "Last port of the range Wings hands out to game servers."
  type        = number
  default     = 25585
}

variable "budget_alert_email" {
  description = "Email notified when spend reaches the budget. Empty disables the budget."
  type        = string
  default     = ""
}

variable "budget_amount" {
  description = "Monthly budget in USD. Kept at 1 on purpose: this deployment should never be billed."
  type        = number
  default     = 1
}
