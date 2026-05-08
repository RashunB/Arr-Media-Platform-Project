terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.105.0"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

provider "proxmox" {
  endpoint      = var.proxmox_endpoint
  api_token     = var.proxmox_api_token
  insecure      = true
  random_vm_ids = true

  ssh {
    agent       = true
    username    = "root"
    private_key = file("../../keys/proxmox")
  }
}

provider "proxmox" {
  alias         = "root"
  endpoint      = var.proxmox_endpoint
  username      = var.proxmox_user
  password      = var.proxmox_password
  insecure      = true
  random_vm_ids = true

  ssh {
    agent       = true
    username    = "root"
    private_key = file("../../keys/proxmox")
  }
}

module "media_vm" {
  source = "../../modules/proxmox_vm"

  vm_name_prefix         = var.vm_name_prefix
  template_os_tag        = var.template_os_tag
  vm_count               = var.vm_count
  vm_ip_start            = var.vm_ip_start
  vm_group               = var.vm_group
  ansible_inventory_path = var.ansible_inventory_path
  datastore_infra        = var.datastore_infra
  datastore_files        = var.datastore_files
  proxmox_node_name      = var.proxmox_node_name
  cloud_init_user_data   = var.cloud_init_user_data_path != null ? file(var.cloud_init_user_data_path) : null

  providers = {
    proxmox      = proxmox
    proxmox.root = proxmox.root
  }
}
