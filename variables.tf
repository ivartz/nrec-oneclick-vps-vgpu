variable "insecure" {
  type    = bool
  default = false
}

variable "deployment_id" {
  type    = string
  default = ""
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
  type    = string
  default = "ubuntu"
}

variable "admin_user" {
  type    = string
  default = "hermes"
}

variable "ollama_model" {
  type    = string
  default = "ornith"
}

variable "obsidian_deb_url" {
  type    = string
  default = "https://github.com/obsidianmd/obsidian-releases/releases/download/v1.12.7/obsidian_1.12.7_amd64.deb"
}

variable "local_vnc_port" {
  type    = number
  default = 55901
}

variable "local_ollama_port" {
  type    = number
  default = 51434
}

variable "operator_public_ip" {
  type    = string
  default = ""
}

variable "operator_public_ipv6" {
  type    = string
  default = ""
}
