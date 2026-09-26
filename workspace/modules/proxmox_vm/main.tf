terraform {
  required_version = ">= 1.15"
  required_providers {
    proxmox = {
      source                = "bpg/proxmox"
      version               = "0.113.1"
      configuration_aliases = [proxmox.root]
    }
  }
}

data "proxmox_virtual_environment_vms" "templates" {
  tags = ["template", var.template_os_tag]

  filter {
    name   = "template"
    values = ["true"]
  }
}

locals {
  vm_tag_list = distinct(concat(var.vm_tag_list, [var.vm_group, var.vm_name_prefix]))
  tag_list    = distinct(concat(var.vm_default_tag_list, local.vm_tag_list))

  matched_templates = data.proxmox_virtual_environment_vms.templates.vms
  template_vm_id    = try(data.proxmox_virtual_environment_vms.templates.vms[0].vm_id, null)

  default_cloud_init_path = "${path.module}/templates/cloud-init.yml.tpl"
  cloud_init_data_path    = coalesce(var.cloud_init_user_data_path, local.default_cloud_init_path)

  gpu_passthrough = length(var.pcie_devices) > 0
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  count        = var.vm_count
  content_type = "snippets"
  datastore_id = var.datastore_files
  node_name    = var.proxmox_node_name

  source_raw {
    file_name = "${var.vm_name_prefix}-${count.index + var.vm_count_offset}-cloud-config.yaml"
    data = templatefile(local.cloud_init_data_path, {
      ssh_public_key = trimspace(var.ssh_public_key)
      hostname       = "${var.vm_name_prefix}-${count.index + var.vm_count_offset}"
      domain         = var.personal_domain
      default_user   = var.vm_default_user
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
  tags            = local.tag_list
  machine         = local.gpu_passthrough ? "q35" : "pc"
  bios            = local.gpu_passthrough ? "ovmf" : "seabios"

  lifecycle {
    precondition {
      condition = length(local.matched_templates) == 1
      error_message = format(
        "Expected exactly one VM tagged [\"template\",%q] with template = true, found %d: %s.",
        var.template_os_tag,
        length(local.matched_templates),
        jsonencode([for t in local.matched_templates : t.name]),
      )
    }
  }

  clone {
    vm_id = local.template_vm_id
    full  = false
  }

  dynamic "disk" {
    for_each = var.additional_disks
    content {
      interface         = disk.key
      datastore_id      = disk.value["datastore_id"]
      path_in_datastore = disk.value["path_in_datastore"]
      file_format       = disk.value["file_format"]
      size              = disk.value["path_in_datastore"] != null ? null : disk.value["size"]
      iothread          = disk.value["path_in_datastore"] != null ? null : disk.value["iothread"]
      discard           = disk.value["path_in_datastore"] != null ? null : disk.value["discard"]
      backup            = disk.value["backup"]
      replicate         = disk.value["replicate"]
      serial            = disk.value["serial"]
    }
  }

  dynamic "hostpci" {
    for_each = var.pcie_devices
    content {
      device  = hostpci.value["device"]
      mapping = hostpci.value["mapping"]
      pcie    = hostpci.value["pcie"]
      rombar  = hostpci.value["rombar"]
    }
  }

  dynamic "efi_disk" {
    for_each = local.gpu_passthrough ? [1] : []
    content {
      datastore_id = var.datastore_infra
      file_format  = "raw"
      type         = "4m"
    }
  }

  cpu {
    cores = var.cpu
    type  = "host"
  }

  memory {
    dedicated = var.memory
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
    datastore_id      = var.datastore_infra
    user_data_file_id = proxmox_virtual_environment_file.cloud_config[count.index].id

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    dns {
      servers = var.dns_servers
    }
  }
}
