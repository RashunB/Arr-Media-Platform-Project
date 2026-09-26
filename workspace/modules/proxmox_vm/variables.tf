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
  type = string
}

variable "vm_tag_list" {
  type        = list(string)
  default     = []
  description = "A set of tags used for organizing and grouping for ansible inventory. Terraform tag is used as default tag to signal managed_nodes"
}

variable "vm_default_tag_list" {
  type        = list(string)
  default     = ["terraform"]
  description = "Default set of tags used for organizing and grouping for ansible inventory. Terraform tag is used as default tag to signal managed_nodes"
}

variable "ssh_public_key" {
  type    = string
  default = ""
}

variable "cloud_init_user_data_path" {
  type        = string
  default     = null
  description = "Path to cloun-init .tpl file. If null, the module default is used."
}

variable "template_os_tag" {
  type        = string
  default     = "default"
  description = "os tag of the template to clone. Defaults to default (ubuntu24) from _base."
}

variable "personal_domain" {
  type    = string
  default = "home.lab"
}

variable "additional_disks" {
  description = "Map of disks keyed by interface name."
  type = map(object({
    datastore_id      = string
    size              = optional(number, 1)
    iothread          = optional(bool, true)
    cache             = optional(string, "none")
    discard           = optional(string, "ignore")
    file_format       = optional(string, "raw")
    path_in_datastore = optional(string, null)
    backup            = optional(bool, false)
    replicate         = optional(bool, false)
    serial            = optional(string, null)
  }))
  default = {}
}

variable "cpu" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 2048
}

variable "pcie_devices" {
  type = map(object({
    device  = optional(string, null)
    mapping = optional(string, null)
    pcie    = optional(bool, true)
  }))
  default = {}
}
