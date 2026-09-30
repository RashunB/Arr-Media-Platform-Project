variable "proxmox_node_name" {
  description = "Proxmox host node name"
  type        = string
}

variable "datastore_infra" {
  description = "Proxmox datastore to store infrastructure components provisioned by Terraform"
  type        = string
  default     = "vmdata"
}

variable "datastore_files" {
  description = "Proxmox datastore to store file components provisioned by Terraform"
  type        = string
  default     = "vmfiles"
}


variable "vm_default_user" {
  description = "Default user for VM setup and configuration"
  type        = string
}

variable "vm_name_prefix" {
  description = "Prefix for the VM name"
  type        = string
}

variable "vm_count" {
  description = "Count for VMs to create. Defaults to one"
  type        = number
  default     = 1
}

variable "vm_count_offset" {
  description = "VM count offset. Used for deploying vms with the same name, but different configurations. This offsets the count to keep it consecutive across two deployments"
  type        = number
  default     = 1
}

variable "vm_group" {
  description = "Group to initially put the VM in"
  type        = string
}

variable "vm_tag_list" {
  description = "A set of tags used for organizing and grouping for ansible inventory. Terraform tag is used as default tag to signal managed_nodes"
  type        = list(string)
  default     = []
}

variable "vm_default_tag_list" {
  description = "Default set of tags used for organizing and grouping for ansible inventory. Terraform tag is used as default tag to signal managed_nodes"
  type        = list(string)
  default     = ["terraform"]
}

variable "ssh_public_key" {
  description = "Public SSH key for the VM default user"
  type        = string
  default     = ""
}

variable "cloud_init_user_data_path" {
  description = "Path to cloud-init .tpl file. If null, the module default is used."
  type        = string
  default     = null
}

variable "template_os_tag" {
  description = "os tag of the template to clone. Defaults to default (ubuntu24) from _base."
  type        = string
  default     = "default"
}

variable "personal_domain" {
  description = "Personal domain to use for VM hostname"
  type        = string
  default     = "home.lab"
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
  description = "Number of CPUs"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Total amount of memory in MBs"
  type        = number
  default     = 2048
}

variable "dns_servers" {
  description = "List of DNS servers written to VMs cloud-init network config"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "pcie_devices" {
  description = "Map object to mount a PCIE device."
  type = map(object({
    device  = optional(string, null)
    mapping = optional(string, null)
    pcie    = optional(bool, true)
    rombar  = optional(bool, true)
  }))
  default = {}
}
