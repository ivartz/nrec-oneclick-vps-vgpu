variable "deployment_id" {
  type        = string
  default     = ""
  description = "Set to an existing deployment name to re-run; leave empty for a fresh random suffix."
}

variable "keys_dir" {
  type    = string
  default = "keys"
}

variable "flavor_name" {
  type    = string
  default = "gr1.L40S.24g.4xlarge"
}

variable "image_name" {
  type    = string
  default = "vGPU Ubuntu 24.04 LTS"
}

variable "availability_zone" {
  type    = string
  default = ""
}

variable "ssh_user" {
  type        = string
  default     = "ubuntu"
  description = "Cloud image default user; receives the OpenStack-injected keypair."
}

variable "admin_user" {
  type        = string
  default     = "hermes"
  description = "Cloud-init created user for RDP/desktop login."
}

variable "ollama_model" {
  type    = string
  default = "north-mini-code"
}

variable "obsidian_deb_url" {
  type        = string
  default     = "https://github.com/obsidianmd/obsidian-releases/releases/latest/download/Obsidian_1.7.5_amd64.deb"
  description = "Direct .deb URL for Obsidian."
}

variable "local_rdp_port" {
  type        = number
  default     = 53389
  description = "Local port that forwards to RDP (3389) on the VM via SSH tunnel."
}

variable "local_ollama_port" {
  type        = number
  default     = 51434
  description = "Local port that forwards to Ollama (11434) on the VM via SSH tunnel."
}

###############################################################################
# Operator IP — resolved automatically by run.sh, or set manually here
###############################################################################

variable "operator_public_ip" {
  description = "Your public IPv4 address (used to restrict SSH security group). Set to '' to allow from anywhere."
  type        = string
  default     = ""
}

variable "operator_public_ipv6" {
  description = "Your public IPv6 address (used to restrict SSH security group). Set to '' if you have no IPv6."
  type        = string
  default     = ""
}
