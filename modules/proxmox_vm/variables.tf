variable "proxmox_node_name" {
  type = string
}
variable "datastore_infra" {
  type    = string
  default = "vmdata"
}

variable "datastore_files" {
  type    = string
  default = "vmfiles"
}

variable "vm_default_user" {
  type = string
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
  type    = string
  default = "managed_nodes"
}

variable "ssh_public_key_path" {
  type    = string
  default = "./keys/ansible_id.pub"
}

variable "cloud_init_user_data_path" {
  type        = string
  default     = null
  description = "Path to cloun-inint .tpl file. If null, the module default is used."
}

variable "template_os_tag" {
  type        = string
  default     = "default"
  description = "os tag of the template to clone. Defaults to default (ubuntu24) from _base."
}

variable "template_os_user" {
  type        = string
  default     = "default"
  description = "default user of the template to clone. Defaults to default (ubuntu24) from _base."
}

variable "personal_domain" {
  type    = string
  default = "baucummail.com"
}