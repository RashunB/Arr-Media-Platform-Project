terraform {
  required_providers {
    proxmox = {
      source                = "bpg/proxmox"
      configuration_aliases = [proxmox.root]
    }
  }
}

data "proxmox_virtual_environment_vms" "templates" {
  tags = ["template", var.template_os_tag]
}

locals {

  template_vm_id = data.proxmox_virtual_environment_vms.templates.vms[0].vm_id

  default_cloud_init_path = "${path.module}/templates/cloud-init.yml.tpl"

  cloud_init_data_path = coalesce(var.cloud_init_user_data_path, local.default_cloud_init_path)
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  count = var.vm_count
  content_type = "snippets"
  datastore_id = var.datastore_files
  node_name    = var.proxmox_node_name

  source_raw {
    file_name = "${var.vm_name_prefix}-${count.index + var.vm_count_offset}-cloud-config.yaml"
    data = templatefile(local.cloud_init_data_path, {
      ssh_public_key = trimspace(file(var.ssh_public_key_path))
      hostname       = "${var.vm_name_prefix}-${count.index + var.vm_count_offset}"
      domain = var.personal_domain
    })

  }
}

resource "proxmox_virtual_environment_vm" "vms" {
  provider        = proxmox.root
  name            = "${var.vm_name_prefix}-${count.index + var.vm_count_offset}"
  node_name       = var.proxmox_node_name
  count           = var.vm_count
  stop_on_destroy = true
  boot_order      = ["virtio0"]
  tags            = ["terraform", var.vm_group, var.template_os_tag]

  clone {
    vm_id = local.template_vm_id
    full  = false
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  agent {
    enabled = true
  }

  initialization {
    datastore_id        = var.datastore_infra
    user_data_file_id = proxmox_virtual_environment_file.cloud_config[count.index].id

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    dns {
      servers = ["192.168.0.1"]
    }
  }
}
