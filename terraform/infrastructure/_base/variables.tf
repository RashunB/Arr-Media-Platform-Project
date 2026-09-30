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
