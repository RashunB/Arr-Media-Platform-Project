terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.105.0"
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
    private_key = file("${path.module}/keys/proxmox")
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
    private_key = file("${path.module}/keys/proxmox")
  }
}

resource "proxmox_download_file" "ubuntu24" {
  content_type = "import"
  datastore_id = var.datastore_files
  node_name    = var.proxmox_node_name
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  file_name    = "noble-server-cloudimg-amd64.qcow2"
  lifecycle { prevent_destroy = true }
}

resource "proxmox_virtual_environment_vm" "ubuntu24_template" {
  provider  = proxmox.root
  name      = "ubuntu24-template"
  node_name = var.proxmox_node_name
  vm_id     = 10000
  template  = true
  started   = false
  tags      = ["terraform", "template", "ubuntu24", "default"]

  lifecycle { prevent_destroy = true }
  operating_system { type = "l26" }
  agent { enabled = true }


  cpu {
    cores = 2
    type  = "host"
  }

  memory { dedicated = 2048 }

  disk {
    datastore_id = var.datastore_infra
    size         = 20
    interface    = "virtio0"
    iothread     = true
    import_from  = proxmox_download_file.ubuntu24.id
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

}

resource "proxmox_download_file" "rocky9" {
  content_type = "import"
  datastore_id = var.datastore_files
  node_name    = var.proxmox_node_name
  url          = "https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"
  file_name    = "Rocky-9-GenericCloud.latest.x86_64.qcow2"
  lifecycle { prevent_destroy = true }
}

resource "proxmox_virtual_environment_vm" "rocky9_template" {
  provider  = proxmox.root
  name      = "rocky9-template"
  node_name = var.proxmox_node_name
  vm_id     = 10001
  template  = true
  started   = false
  tags      = ["terraform", "template", "rocky9"]

  lifecycle { prevent_destroy = true }
  operating_system { type = "l26" }
  agent { enabled = true }


  cpu {
    cores = 2
    type  = "host"
  }

  memory { dedicated = 2048 }

  disk {
    datastore_id = var.datastore_infra
    size         = 20
    interface    = "virtio0"
    iothread     = true
    import_from  = proxmox_download_file.rocky9.id
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

}