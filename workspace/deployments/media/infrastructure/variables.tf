variable "proxmox_endpoint" {
  description = "Endpoint for the proxmox host in format of 'https://hostname:port/'"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox host API token for routine connectivity"
  type        = string
  sensitive   = true
}

variable "proxmox_user" {
  description = "Proxmox user for escalated, privileged actions"
  type        = string
}

variable "proxmox_password" {
  description = "Password for proxmox user defined for escalated, privileged actions"
  type        = string
  sensitive   = true
}

variable "proxmox_node_name" {
  description = "Proxmox host node name"
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS certificate verification for Proxmox API"
  type        = bool
  default     = true
}

variable "datastore_infra" {
  description = "Proxmox datastore to store infrastructure components provisioned by Terraform"
  type        = string
}

variable "datastore_files" {
  description = "Proxmox datastore to store file components provisioned by Terraform"
  type        = string
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
  description = "Counf for VMs to create. Defaults to one"
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
  default     = ["192.168.0.1", "8.8.8.8"]
}

# Cloudflare/DNS

variable "cloudflare_dns_type" {
  description = "Cloudflare DNS type, pertains to the record to create: A, CNAME, AAAA, MX, etc."
  type        = string
  default     = "A"
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "cloudflare_ttl" {
  description = "Cloudflare Time-to-Live in seconds"
  type        = number
  default     = 600
}

variable "cloudflare_proxied" {
  description = "Cloudflare toggle to proxy a DNS record. Defaults to false for local addresses"
  type        = bool
  default     = false
}

variable "cloudflare_dns_comment" {
  description = "Cloudflare DNS comment for the DNS record created"
  type        = string
  default     = "Created with Terraform"
}
