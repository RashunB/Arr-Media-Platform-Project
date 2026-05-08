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