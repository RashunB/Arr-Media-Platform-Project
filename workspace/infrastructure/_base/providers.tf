terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.111.0"
    }
    local = { source = "hashicorp/local" }
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
    private_key = file("/baucumlabs/secrets/proxmox")
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
    private_key = file("/baucumlabs/secrets/proxmox")
  }
}
