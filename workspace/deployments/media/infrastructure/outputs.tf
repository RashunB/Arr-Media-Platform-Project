output "vm" {
  value = module.media_vm
}

output "data_proxmox_hardware_mapping_pci" {
  value = data.proxmox_hardware_mapping_pci.transcoding_gpu
}