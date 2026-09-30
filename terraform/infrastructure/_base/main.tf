resource "proxmox_download_file" "ubuntu24" {
  content_type = "import"
  datastore_id = var.datastore_files
  node_name    = var.proxmox_node_name
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  file_name    = "noble-server-cloudimg-amd64.qcow2"
  lifecycle { prevent_destroy = true }
  overwrite = false
}

resource "proxmox_virtual_environment_vm" "ubuntu24_template" {
  provider  = proxmox.root
  name      = "ubuntu24-template"
  node_name = var.proxmox_node_name
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

  serial_device {
    device = "socket"
  }
}

resource "proxmox_download_file" "rocky9" {
  content_type = "import"
  datastore_id = var.datastore_files
  node_name    = var.proxmox_node_name
  url          = "https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"
  file_name    = "Rocky-9-GenericCloud.latest.x86_64.qcow2"
  lifecycle { prevent_destroy = true }
  overwrite = false
}

resource "proxmox_virtual_environment_vm" "rocky9_template" {
  provider  = proxmox.root
  name      = "rocky9-template"
  node_name = var.proxmox_node_name
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

  serial_device {
    device = "socket"
  }
}
