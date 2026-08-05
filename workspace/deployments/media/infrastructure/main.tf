terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.111.0"
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
    private_key = file("/baucumlabs/workspace/keys/proxmox")
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
    private_key = file("/baucumlabs/workspace/keys/proxmox")
  }
}

module "media_vm" {
  source = "/baucumlabs/workspace/modules/proxmox_vm"

  vm_name_prefix            = var.vm_name_prefix
  template_os_tag           = var.template_os_tag
  vm_count                  = var.vm_count
  vm_default_user           = var.vm_default_user
  vm_group                  = var.vm_group
  vm_tag_list               = var.vm_tag_list
  datastore_infra           = var.datastore_infra
  datastore_files           = var.datastore_files
  proxmox_node_name         = var.proxmox_node_name
  cloud_init_user_data_path = var.cloud_init_user_data_path
  vm_count_offset           = var.vm_count_offset
  ssh_public_key_path       = var.ssh_public_key_path
  personal_domain           = var.personal_domain
  additional_disks          = var.additional_disks

  providers = {
    proxmox      = proxmox
    proxmox.root = proxmox.root
  }
}

