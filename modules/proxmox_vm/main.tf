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

  vm_count_offset = var.vm_count_offset + 1
  template_vm_id = data.proxmox_virtual_environment_vms.templates.vms[0].vm_id
  default_cloud_init = <<-EOF
    #cloud-config
    packages:
      - qemu-guest-agent
    runcmd:
      - systemctl enable qemu-guest-agent
      - systemctl start qemu-guest-agent
    EOF

  cloud_init_data = coalesce(var.cloud_init_user_data, local.default_cloud_init)
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = var.datastore_files
  node_name    = var.proxmox_node_name

  source_raw {
    file_name = "${var.vm_name_prefix}-cloud-config.yaml"
    data      = local.cloud_init_data
  }
}

resource "proxmox_virtual_environment_vm" "vms" {
  provider        = proxmox.root
  name            = "${var.vm_name_prefix}-${count.index + local.vm_count_offset}"
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


  # dynamic "disk" {
  #   for_each = count.index == var.vm_count - 1 ? [1] : []

  #   content {
  #     datastore_id = var.datastore_infra
  #     size         = 2
  #     interface    = "virtio1"
  #     iothread     = true
  #     discard      = "on"
  #   }
  # }

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
    vendor_data_file_id = proxmox_virtual_environment_file.cloud_config.id

    user_account {
      username = "rocky"
      keys     = [file(var.ssh_public_key)]
    }

    ip_config {
      ipv4 {
        address = "192.168.0.${var.vm_ip_start + count.index}/24"
        gateway = "192.168.0.1"
      }
    }

    dns {
      servers = ["192.168.0.1"]
    }
  }
}

resource "local_file" "ansible_inventory" {
  filename        = var.ansible_inventory_path
  file_permission = "0777"
  content = templatefile("${path.module}/templates/inventory.tpl", {
    node_ips = [for i in range(var.vm_count) : "192.168.0.${var.vm_ip_start + i}"]
    offset    = local.vm_count_offset
    group    = var.vm_group
    prefix   = var.vm_name_prefix
  })
}