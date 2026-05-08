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
  default = "managed_nodes"
}

variable "vm_ip_start" {
  type = number
}

variable "ssh_public_key" {
  type    = string
  default = "/home/terraform/workspace/keys/ansible_id.pub"
}

variable "ansible_inventory_path" {
  type = string
  default = "/home/ansible/ansible/inventory/"
}

variable "cloud_init_user_data" {
  type        = string
  default     = null
  description = "Optional cloud-init #cloud-config YAML string. If null, a default is used."
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