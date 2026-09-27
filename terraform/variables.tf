variable "tenancy_ocid" {
  description = "OCID da tenancy (conta raiz) da Oracle Cloud."
  type        = string
}

variable "user_ocid" {
  description = "OCID do usuário dono da API key."
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint da API key cadastrada na console."
  type        = string
}

variable "private_key_path" {
  description = "Caminho local da chave privada .pem da API key."
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "region" {
  description = "Região OCI onde o servidor sobe (ex.: sa-saopaulo-1, sa-vinhedo-1)."
  type        = string
  default     = "sa-saopaulo-1"
}

variable "compartment_ocid" {
  description = "OCID do compartment. Vazio usa a própria tenancy (raiz)."
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "Conteúdo da chave pública SSH que terá acesso à VM."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "Faixa de IPs liberada para SSH. Prefira SEU_IP/32 a 0.0.0.0/0."
  type        = string
  default     = "0.0.0.0/0"
}

variable "instance_name" {
  description = "Nome da VM na console da Oracle."
  type        = string
  default     = "minecraft-paper"
}

variable "instance_ocpus" {
  description = "Núcleos ARM (Ampere A1). Teto do Always Free: 4."
  type        = number
  default     = 4
}

variable "instance_memory_gb" {
  description = "RAM em GB. Teto do Always Free: 24."
  type        = number
  default     = 24
}

variable "boot_volume_gb" {
  description = "Disco em GB. Always Free dá 200 GB no total; mínimo por VM é 50."
  type        = number
  default     = 100
}

variable "ubuntu_version" {
  description = "Versão do Ubuntu usada como imagem base."
  type        = string
  default     = "24.04"
}

variable "availability_domain_index" {
  description = "Availability domain a usar (0, 1, 2...). Troque se der 'Out of host capacity'."
  type        = number
  default     = 0
}

variable "minecraft_port" {
  description = "Porta do servidor Java Edition."
  type        = number
  default     = 25565
}

variable "minecraft_version" {
  description = "Versão do Minecraft. LATEST pega a mais recente suportada pelo Paper."
  type        = string
  default     = "LATEST"
}

variable "java_memory" {
  description = "Heap da JVM. Deixe folga para o SO e o Docker."
  type        = string
  default     = "12G"
}

variable "motd" {
  description = "Mensagem exibida na lista de servidores do cliente."
  type        = string
  default     = "Servidor dos amigos - Paper"
}

variable "difficulty" {
  description = "Dificuldade do mundo: peaceful, easy, normal ou hard."
  type        = string
  default     = "normal"

  validation {
    condition     = contains(["peaceful", "easy", "normal", "hard"], var.difficulty)
    error_message = "Use peaceful, easy, normal ou hard."
  }
}

variable "max_players" {
  description = "Limite de jogadores simultâneos."
  type        = number
  default     = 20
}

variable "ops" {
  description = "Nicks separados por vírgula que viram operadores do servidor."
  type        = string
  default     = ""
}

variable "whitelist" {
  description = "Nicks separados por vírgula liberados a entrar. Vazio deixa o servidor aberto."
  type        = string
  default     = ""
}

variable "rcon_password" {
  description = "Senha do RCON. Usada só dentro da rede interna do Docker."
  type        = string
  default     = "troque-esta-senha"
  sensitive   = true
}
