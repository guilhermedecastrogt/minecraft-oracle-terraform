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
  description = "OCI region to deploy into (e.g. sa-saopaulo-1, us-ashburn-1)."
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
  default     = "minecraft-paper"
}

variable "instance_ocpus" {
  description = "ARM cores (Ampere A1). Always Free cap: 4."
  type        = number
  default     = 4
}

variable "instance_memory_gb" {
  description = "Memory in GB. Always Free cap: 24."
  type        = number
  default     = 24
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

variable "minecraft_port" {
  description = "Java Edition server port."
  type        = number
  default     = 25565
}

variable "minecraft_version" {
  description = "Minecraft version. LATEST resolves to the newest release Paper supports."
  type        = string
  default     = "LATEST"
}

variable "java_memory" {
  description = "JVM heap size. Leave headroom for the OS and Docker."
  type        = string
  default     = "12G"
}

variable "motd" {
  description = "Message shown in the client's server list."
  type        = string
  default     = "Paper server on Oracle Cloud"
}

variable "difficulty" {
  description = "World difficulty: peaceful, easy, normal or hard."
  type        = string
  default     = "normal"

  validation {
    condition     = contains(["peaceful", "easy", "normal", "hard"], var.difficulty)
    error_message = "Must be one of: peaceful, easy, normal, hard."
  }
}

variable "max_players" {
  description = "Maximum number of concurrent players."
  type        = number
  default     = 20
}

variable "ops" {
  description = "Comma-separated usernames granted operator rights."
  type        = string
  default     = ""
}

variable "whitelist" {
  description = "Comma-separated usernames allowed to join. Empty leaves the server open."
  type        = string
  default     = ""
}

variable "timezone" {
  description = "Timezone used by the containers for logs and backup scheduling."
  type        = string
  default     = "America/Sao_Paulo"
}

variable "rcon_password" {
  description = "RCON password. Only reachable from inside the Docker network."
  type        = string
  default     = "change-this-password"
  sensitive   = true
}
