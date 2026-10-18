module "media_vm" {
  source = "git::https://github.com/RashunB/terraform-proxmox-module.git?ref=78217240834729f7601417de009d36aa8faaf3c6"

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
  ssh_public_key            = local.public_key
  personal_domain           = var.personal_domain
  additional_disks          = var.additional_disks
  cpu                       = var.cpu
  memory                    = var.memory
  pcie_devices              = local.pcie_devices
  dns_servers               = var.dns_servers

  providers = {
    proxmox      = proxmox
    proxmox.root = proxmox.root
  }
}
