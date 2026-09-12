data "proxmox_hardware_mapping_pci" "transcoding_gpu" {
  name = "transcoding_gpu"
}

locals {
  pcie_map = [
    data.proxmox_hardware_mapping_pci.transcoding_gpu.name,
  ]

  pcie_devices = {
    for idx, name in local.pcie_map : "hostpci{$idx}" => {
      device  = "hostpci${idx}"
      mapping = name
      pcie    = true
    }
  }
}

module "media_vm" {
  source = "../../../modules/proxmox_vm"

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
  cpu                       = var.cpu
  memory                    = var.memory
  pcie_devices              = local.pcie_devices

  providers = {
    proxmox      = proxmox
    proxmox.root = proxmox.root
  }
}
