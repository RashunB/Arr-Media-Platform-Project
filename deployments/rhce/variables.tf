variable "proxmox_endpoint" {
  type = string
}

variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

variable "proxmox_user" {
  type = string
}

variable "proxmox_password" {
  type      = string
  sensitive = true
}

variable "proxmox_node_name" {
  type = string
}

variable "datastore_infra" {
  type = string
}

variable "datastore_files" {
  type = string
}

variable "ssh_public_key_path" {
  type = string
}

variable "vm_default_user" {
  type    = string
  default = "ansible"
}

variable "vm_name_prefix" {
  type = string
}

variable "vm_count" {
  type    = number
  default = 1
}

variable "vm_count_offset" {
  type    = number
  default = 1
}

variable "vm_group" {
  type = string
}

variable "cloud_init_user_data_path" {
  type        = string
  default     = null
  description = "Optional cloud-init #cloud-config YAML filepath. If null, a default is used."
}

variable "template_os_tag" {
  type        = string
  default     = "default"
  description = "os tag of the template to clone. Defaults to default (ubuntu24) from _base."
}

variable "personal_domain" {
  type    = string
  default = "baucummail.com"
}